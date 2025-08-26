// lib/utils/constants.dart
import 'dart:io' show Platform; // For checking platform type

class Constants {
  // Django Backend API ရဲ့ Base URL ကို သတ်မှတ်ခြင်း။
  // သင့်ရဲ့ Django server run နေတဲ့ IP address နဲ့ Port ကို ပြောင်းလဲပါ။
  //
  // Android Emulator အတွက်: 10.0.2.2 က host machine ရဲ့ localhost ကို ကိုယ်စားပြုပါတယ်။
  // iOS Simulator အတွက်: localhost (သို့မဟုတ် 127.0.0.1) က host machine ရဲ့ localhost ကို ကိုယ်စားပြုပါတယ်။
  // Physical Device (ဖုန်းအစစ်) အတွက်: သင့် PC ရဲ့ IP Address ကို တိုက်ရိုက်ထည့်သွင်းရပါမယ်။
  // ဥပမာ: 'http://192.168.1.100:8000/api'
  //
  // သင့် PC ရဲ့ IP address ကို သိရှိရန်:
  // - Windows: Command Prompt မှာ `ipconfig` လို့ ရိုက်ပါ။
  // - macOS/Linux: Terminal မှာ `ifconfig` သို့မဟုတ် `ip addr` လို့ ရိုက်ပါ။
  // Wi-Fi adapter (ဥပမာ: Wireless LAN adapter Wi-Fi) ရဲ့ IPv4 Address ကို ရှာပါ။

  static const String _localHostAndroid = '10.0.2.2';
  static const String _localHostIOS = 'localhost'; // Or '127.0.0.1'

  // Physical Device အတွက် သင့် PC ရဲ့ IP Address ကို ဤနေရာတွင် ထည့်သွင်းပါ။
  // သင့် PC ရဲ့ IP Address ပြောင်းလဲသွားနိုင်တာကြောင့် လိုအပ်ရင် ပြင်ဆင်ပါ။
  static const String _physicalDeviceHost = '192.168.1.5'; // ဥပမာ: '192.168.1.100'

  // _baseHost သည် host name/IP ကိုသာ ပြန်ပေးရပါမည်။
  static String get _baseHost {
    if (Platform.isAndroid) {
      return _localHostAndroid;
    } else if (Platform.isIOS) {
      return _localHostIOS;
    } else {
      // Physical device or other platforms
      // Warning: For physical devices, you MUST change '_physicalDeviceHost' to your actual PC's IP.
      // If running on a web browser or desktop, 'localhost' might work, but for physical mobile, it needs the actual IP.
      print('WARNING: For physical devices, please set _physicalDeviceHost in lib/utils/constants.dart');
      // Fallback to localhost for development on non-mobile platforms (like desktop Flutter)
      return 'localhost'; // Host name ကိုပဲ ပြန်ပေးပါ။
    }
  }

  static const String _port = '8000'; // Django server ရဲ့ Port နံပါတ်
  static const String _apiPath = '/api'; // Django project ရဲ့ API base path

  // baseUrl သည် http://, host, port, path အားလုံးကို ပေါင်းစပ်ပေးပါမည်။
  static String get baseUrl {
    // _baseHost သည် 'localhost' ဖြစ်ပြီး physical device အတွက် IP မသတ်မှတ်ရသေးပါက warning ပြသပါ။
    if (_baseHost == 'localhost' && !Platform.isAndroid && !Platform.isIOS && _physicalDeviceHost == '192.168.1.5') {
      print('WARNING: For physical devices, please set _physicalDeviceHost to your actual PC\'s IP address.');
    }
    
    // Physical device အတွက် IP သတ်မှတ်ထားပါက ထို IP ကို အသုံးပြုပါ။
    String hostToUse = (Platform.isAndroid || Platform.isIOS) ? _baseHost : _physicalDeviceHost;
    if (hostToUse == '192.168.1.5' && !Platform.isAndroid && !Platform.isIOS) {
        // Desktop or Web development, use localhost for _baseHost
        hostToUse = _baseHost;
    }

    return 'http://$hostToUse:$_port$_apiPath';
  }

  // Djoser ရဲ့ Login URL ကို ပြင်ဆင်ခြင်း
  static final String loginUrl = '$baseUrl/auth/token/login/'; 
  static final String logoutUrl = '$baseUrl/auth/token/logout/'; 
  static final String groupsUrl = '$baseUrl/sheets/groups/';
  static final String paymentAccountsUrl = '$baseUrl/sheets/payment-accounts/';
  static final String usersUrl = '$baseUrl/auth/users/'; // For managing auditor accounts
  static final String transactionsUrl = '$baseUrl/sheets/transactions/';
  static final String auditEntriesUrl = '$baseUrl/sheets/audit-entries/';
  static final String auditSummaryUrl = '$baseUrl/sheets/audit-summary/';
}
