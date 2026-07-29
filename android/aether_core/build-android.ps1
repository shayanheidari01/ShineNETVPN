[CmdletBinding()]
param(
    [ValidateSet('arm64-v8a', 'armeabi-v7a', 'x86_64')]
    [string]$Abi = 'arm64-v8a',
    [int]$Api = 24
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$crate = Join-Path $PSScriptRoot 'aether'
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$ndk = Join-Path $sdk 'ndk\30.0.14904198'
$binNative = Join-Path $ndk 'toolchains\llvm\prebuilt\windows-x86_64\bin'
$cmakeNative = Join-Path $sdk 'cmake\3.22.1\bin\cmake.exe'
$bundledLlvmBin = Join-Path $sdk 'ndk\30.0.14904198\toolchains\llvm\prebuilt\windows-x86_64\bin'
$llvmBinNative = if ($env:AETHER_LLVM_BIN) {
    $env:AETHER_LLVM_BIN
} elseif (Test-Path -LiteralPath (Join-Path $bundledLlvmBin 'libclang.dll')) {
    $bundledLlvmBin
} else {
    $binNative
}

$target = switch ($Abi) {
    'arm64-v8a' { 'aarch64-linux-android' }
    'armeabi-v7a' { 'armv7-linux-androideabi' }
    'x86_64' { 'x86_64-linux-android' }
}
$clangTriple = switch ($Abi) {
    'arm64-v8a' { 'aarch64-linux-android' }
    'armeabi-v7a' { 'armv7a-linux-androideabi' }
    'x86_64' { 'x86_64-linux-android' }
}
$envSuffix = $target.Replace('-', '_')
$clangTarget = "$clangTriple$Api"

foreach ($path in @($ndk, $binNative, $cmakeNative, $llvmBinNative, (Join-Path $llvmBinNative 'libclang.dll'))) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Android build requirement missing: $path"
    }
}

$ndkSlash = $ndk.Replace('\', '/')
$env:ANDROID_NDK_HOME = $ndkSlash
$env:ANDROID_NDK_ROOT = $ndkSlash
$env:LIBCLANG_PATH = $llvmBinNative.Replace('\', '/')
$env:CMAKE = $cmakeNative.Replace('\', '/')
$env:CMAKE_GENERATOR = 'Ninja'
$env:PATH = "$(Split-Path $cmakeNative -Parent);$env:PATH"

# boring-sys builds BoringSSL before its known Windows second-configure failure.
Push-Location $crate
try {
    $ErrorActionPreference = 'Continue'
    $oldNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    & cargo ndk -t $Abi --platform $Api build --release --lib
    $bootstrapExit = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $oldNativeErrorPreference
    $ErrorActionPreference = 'Stop'
}
finally {
    Pop-Location
}
$bsslOut = Get-ChildItem -LiteralPath (Join-Path $crate "target\$target\release\build") -Directory -Filter 'boring-sys-*' |
    ForEach-Object { Join-Path $_.FullName 'out' } |
    Where-Object { Test-Path -LiteralPath (Join-Path $_ 'build\libssl.a') } |
    Select-Object -Last 1

if (-not $bsslOut) {
    throw "BoringSSL bootstrap failed before static libraries were produced (cargo exit $bootstrapExit)."
}

$sysroot = (Join-Path $ndk 'toolchains\llvm\prebuilt\windows-x86_64\sysroot').Replace('\', '/')
$env:BORING_BSSL_PATH = Join-Path $bsslOut 'build'
$env:BORING_BSSL_INCLUDE_PATH = Join-Path $bsslOut 'boringssl\src\include'
$env:BORING_BSSL_ASSUME_PATCHED = '1'
$bin = $binNative.Replace('\', '/')
$env:CLANG_PATH = "$bin/clang.exe"
$linker = "$bin/$clangTarget-clang.cmd"
$ar = "$bin/llvm-ar.exe"
Set-Item -Path "Env:CARGO_TARGET_${envSuffix}_LINKER" -Value $linker
Set-Item -Path "Env:CARGO_TARGET_${envSuffix}_AR" -Value $ar
Set-Item -Path "Env:AR_${envSuffix}" -Value $ar
Set-Item -Path "Env:CC_${envSuffix}" -Value "$bin/clang.exe"
Set-Item -Path "Env:CXX_${envSuffix}" -Value "$bin/clang++.exe"
# cargo-ndk/boring-sys also consult the hyphenated target variables. Keep
# those paths slash-normalized so CMake does not parse Windows `\U` escapes.
Set-Item -Path "Env:CC_$target" -Value "$bin/clang.exe"
Set-Item -Path "Env:CXX_$target" -Value "$bin/clang++.exe"
Set-Item -Path "Env:CFLAGS_$envSuffix" -Value "--target=$clangTarget"
Set-Item -Path "Env:CXXFLAGS_$envSuffix" -Value "--target=$clangTarget"
Set-Item -Path "Env:BINDGEN_EXTRA_CLANG_ARGS_$envSuffix" -Value "--target=$clangTarget --sysroot=$sysroot -I$sysroot/usr/include/$target"
$env:RUSTFLAGS = "$env:RUSTFLAGS -C link-arg=-Wl,-soname,libaether.so -C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wl,-z,common-page-size=16384".Trim()

Push-Location $crate
try {
    cargo build --release --lib --target $target
    $destination = Join-Path $PSScriptRoot "android-libs\$Abi"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -LiteralPath ".\target\$target\release\libaether.so" -Destination (Join-Path $destination 'libaether.so') -Force

    $jniDestination = Join-Path $root "app\src\main\jniLibs\$Abi"
    New-Item -ItemType Directory -Path $jniDestination -Force | Out-Null
    Copy-Item -LiteralPath ".\target\$target\release\libaether.so" -Destination (Join-Path $jniDestination 'libaether.so') -Force
}
finally {
    Pop-Location
}
