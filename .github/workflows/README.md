# راهنمای تنظیم GitHub Actions برای ساخت خودکار APK

## تنظیم Secrets در GitHub

برای استفاده از این workflow، باید secrets زیر را در مخزن GitHub خود تنظیم کنید:

1. به صفحه مخزن GitHub بروید
2. به **Settings** > **Secrets and variables** > **Actions** بروید
3. روی **New repository secret** کلیک کنید
4. secrets زیر را اضافه کنید:

### Secrets مورد نیاز:

| نام Secret | توضیحات |
|-----------|---------|
| `KEYALIAS` | نام alias کلید در keystore |
| `KEYPASSWORD` | رمز عبور کلید (key password) |
| `STOREPASSWORD` | رمز عبور keystore (store password) |
| `KEYSTORE_BASE64` | محتوای فایل keystore.jks به صورت base64 encoded |

### نحوه دریافت KEYSTORE_BASE64:

در سیستم محلی خود، دستور زیر را اجرا کنید تا فایل keystore را به base64 تبدیل کنید:

```bash
base64 -w 0 path/to/your/keystore.jks
```

خروجی دستور بالا را کپی کرده و به عنوان مقدار `KEYSTORE_BASE64` در secrets ذخیره کنید.

## نحوه اجرای Workflow

### روش 1: Push Tag (توصیه شده)

برای ساخت یک نسخه جدید، یک tag با فرمت `v*` ایجاد و push کنید:

```bash
# افزایش version در pubspec.yaml
git add pubspec.yaml
git commit -m "Bump version to 1.1.4"
git tag v1.1.4
git push origin v1.1.4
```

با push کردن tag، workflow به صورت خودکار اجرا می‌شود.

### روش 2: اجرای دستی (Workflow Dispatch)

1. به صفحه **Actions** در GitHub بروید
2. workflow **Build and Release APK** را انتخاب کنید
3. روی **Run workflow** کلیک کنید
4. شاخه مورد نظر را انتخاب و اجرا کنید

## خروجی‌ها

پس از اجرای موفق workflow:

1. **GitHub Release**: یک release جدید با tag مربوطه ساخته می‌شود
2. **APK File**: فایل APK با نام `ShineNET_v{version}_{build_number}.apk` به release ضمیمه می‌شود
3. **Artifact**: فایل APK به عنوان artifact نیز برای 30 روز ذخیره می‌شود

## امنیت

این workflow با رعایت نکات امنیتی زیر طراحی شده است:

- ✅ تمام اطلاعات حساس (رمزها، keystore) از طریق GitHub Secrets مدیریت می‌شوند
- ✅ فایل‌های حساس پس از ساخت APK به صورت خودکار حذف می‌شوند
- ✅ دسترسی‌های فایل‌های موقت به حداقل محدود شده است (chmod 600)
- ✅ هیچ اثری از اطلاعات حساس در لاگ‌های workflow باقی نمی‌ماند
- ✅ از متغیرهای محیطی برای انتقال امن اطلاعات استفاده شده است

## عیب‌یابی

### خطا در ساخت APK

اگر workflow با خطا مواجه شد:

1. بررسی کنید که تمام secrets به درستی تنظیم شده باشند
2. مطمئن شوید فایل `android/app/build.gradle` دارای signingConfig مناسب باشد
3. لاگ‌های GitHub Actions را بررسی کنید

### خطا در امضای APK

اگر خطای مربوط به امضا دریافت کردید:

1. از صحت `KEYSTORE_BASE64` اطمینان حاصل کنید
2. بررسی کنید که `KEYALIAS`، `KEYPASSWORD` و `STOREPASSWORD` صحیح باشند

## تغییر نسخه (Versioning)

برای افزایش نسخه:

1. فایل `pubspec.yaml` را باز کنید
2. خط `version` را به روز کنید (مثلاً `1.1.3+113` → `1.1.4+114`)
3. تغییرات را commit و tag جدید push کنید

```yaml
version: 1.1.4+114
```
