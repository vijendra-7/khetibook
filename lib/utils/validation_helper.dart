
class ValidationHelper {
  static String? validateRequired(String? value, bool isGujarati) {
    if (value == null || value.trim().isEmpty) {
      return isGujarati ? 'જરૂરી છે' : 'Required';
    }
    return null;
  }

  static String? validateAmount(String? value, bool isGujarati) {
    if (value == null || value.trim().isEmpty) {
      return isGujarati ? 'જરૂરી છે' : 'Required';
    }
    final num = double.tryParse(value);
    if (num == null) {
      return isGujarati ? 'અંક દાખલ કરો' : 'Enter a valid number';
    }
    if (num <= 0) {
      return isGujarati ? '૦ થી વધારે હોવી જોઈએ' : 'Must be greater than 0';
    }
    return null;
  }

  static String? validateOptionalAmount(String? value, bool isGujarati) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final num = double.tryParse(value);
    if (num == null) {
      return isGujarati ? 'અંક દાખલ કરો' : 'Enter a valid number';
    }
    if (num <= 0) {
      return isGujarati ? '૦ થી વધારે હોવી જોઈએ' : 'Must be greater than 0';
    }
    return null;
  }

  static String? validateWeight(String? value, bool isGujarati) {
    if (value == null || value.trim().isEmpty) {
      return isGujarati ? 'જરૂરી છે' : 'Required';
    }
    final num = double.tryParse(value);
    if (num == null) {
      return isGujarati ? 'અંક દાખલ કરો' : 'Enter a valid number';
    }
    if (num < 0) {
      return isGujarati ? '૦ થી વધારે હોવી જોઈએ' : 'Must be at least 0';
    }
    return null;
  }
}
