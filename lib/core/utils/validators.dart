class Validators {
  Validators._();

  static String? required(String? value, {String field = 'هذا الحقل'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field مطلوب';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, field: 'البريد الإلكتروني');
    if (requiredError != null) return requiredError;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value!.trim())) {
      return 'البريد الإلكتروني غير صالح';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = required(value, field: 'كلمة المرور');
    if (requiredError != null) return requiredError;

    if (value!.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على أحرف وأرقام';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final requiredError = required(value, field: 'تأكيد كلمة المرور');
    if (requiredError != null) return requiredError;
    if (value != original) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }

  static String? fullName(String? value) {
    final requiredError = required(value, field: 'الاسم');
    if (requiredError != null) return requiredError;
    if (value!.trim().length < 2) {
      return 'الاسم قصير جداً';
    }
    return null;
  }

  static String? phone(String? value) {
    final requiredError = required(value, field: 'رقم الهاتف');
    if (requiredError != null) return requiredError;
    final cleaned = value!.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleaned)) {
      return 'رقم الهاتف غير صالح';
    }
    return null;
  }

  static String? shopName(String? value) {
    final requiredError = required(value, field: 'اسم المحل');
    if (requiredError != null) return requiredError;
    if (value!.trim().length < 2) {
      return 'اسم المحل قصير جداً';
    }
    return null;
  }
}
