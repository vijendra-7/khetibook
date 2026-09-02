import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AnyrorApiService {
  final String _baseUrl = 'https://anyror.gujarat.gov.in';
  String currentUrl = 'https://anyror.gujarat.gov.in/LandRecordRural.aspx';
  
  void setTargetUrl(String url) {
    currentUrl = url;
  }
  
  final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  String _viewState = '';
  String _viewStateGenerator = '';
  String _eventValidation = '';
  String _cookie = '';
  final Map<String, String> _cookieMap = {};

  // Current parsed options
  List<Map<String, String>> applicationTypes = [];
  List<Map<String, String>> districts = [];
  List<Map<String, String>> talukas = [];
  List<Map<String, String>> villages = [];
  List<Map<String, String>> surveyNumbers = [];
  List<Map<String, String>> sheets = [];
  List<Map<String, String>> radioOptions = [];

  Uint8List? captchaImageBytes;
  
  // HTML names for selects
  String districtSelectName = '';
  String talukaSelectName = '';
  String villageSelectName = '';
  String surveySelectName = '';
  String sheetSelectName = '';
  String captchaInputName = '';
  String saveButtonName = '';
  String applicationTypeSelectName = '';
  String radioGroupName = '';
  
  final Map<String, String> _allInputs = {};
  Map<String, String> _lastFormSelections = {};
  String _lastCaptchaText = '';

  // Getters

  Future<String?> loadInitialPage() async {
    try {
      final response = await http.get(Uri.parse(currentUrl), headers: _headers);
      
      if (response.statusCode != 200) {
        return 'HTTP Status ${response.statusCode}';
      }
      
      _updateCookies(response);
      _parseHtmlFields(response.body);
      _extractOptions(response.body);
      await _loadCaptcha(response.body);
      return null;
    } catch (e, st) {
      print('Load Initial Error: $e\n$st');
      return e.toString();
    }
  }

  void _updateCookies(http.Response response) {
    String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      // Dart http package joins multiple set-cookie headers with commas.
      // E.g. "ASP.NET_SessionId=..., cookiesession1=..."
      // Commas also appear in dates (Expires=Wed, 21 ...), so we split carefully.
      var parts = rawCookie.split(RegExp(r',(?=\s*[a-zA-Z0-9_\-]+=[^;]+)'));
      for (var part in parts) {
        var cookiePart = part.split(';')[0].trim(); // This correctly drops path=/, HttpOnly, etc.
        if (cookiePart.contains('=')) {
          int eqIndex = cookiePart.indexOf('=');
          String key = cookiePart.substring(0, eqIndex).trim();
          String value = cookiePart.substring(eqIndex + 1).trim();
          _cookieMap[key] = value;
        }
      }
      _cookie = _cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      _headers['Cookie'] = _cookie;
    }
  }

  void _parseHtmlFields(String htmlString) {
    _allInputs.clear(); // Important: clear old inputs so disabled fields from previous state are dropped
    var document = parser.parse(htmlString);
    
    var viewStateInput = document.querySelector('input[name="__VIEWSTATE"]');
    if (viewStateInput != null) _viewState = viewStateInput.attributes['value'] ?? '';

    var viewStateGenInput = document.querySelector('input[name="__VIEWSTATEGENERATOR"]');
    if (viewStateGenInput != null) _viewStateGenerator = viewStateGenInput.attributes['value'] ?? '';

    var eventValidationInput = document.querySelector('input[name="__EVENTVALIDATION"]');
    if (eventValidationInput != null) _eventValidation = eventValidationInput.attributes['value'] ?? '';
    
    // Find all inputs (hidden, text, radio, etc) to ensure ASP.NET validation passes
    var inputs = document.querySelectorAll('input');
    for (var input in inputs) {
      String name = input.attributes['name'] ?? '';
      if (name.isEmpty) continue;
      String type = (input.attributes['type'] ?? '').toLowerCase();
      String value = input.attributes['value'] ?? '';
      
      if (type == 'submit' || type == 'button') continue;
      
      // Skip disabled inputs, as sending them triggers ASP.NET Event Validation errors
      if (input.attributes.containsKey('disabled')) continue;
      
      if (type == 'radio' || type == 'checkbox') {
        if (input.attributes.containsKey('checked')) {
          _allInputs[name] = value;
        }
      } else {
        _allInputs[name] = value;
      }
    }
    
    // Find select names (they change sometimes, but usually end in ddlDistrict, etc.)
    var selects = document.querySelectorAll('select');
    for (var s in selects) {
      String name = s.attributes['name'] ?? '';
      if (name.isEmpty) continue;
      
      String lowerName = name.toLowerCase();
      if (lowerName.contains('district')) {
        districtSelectName = name;
      } else if (lowerName.contains('taluka') || lowerName.contains('csoffice')) {
        talukaSelectName = name;
      } else if (lowerName.contains('village') || lowerName.contains('ward')) {
        villageSelectName = name;
      } else if (lowerName.contains('survey') || lowerName.contains('block') || lowerName.contains('sno')) {
        surveySelectName = name;
      } else if (lowerName.contains('sheet')) {
        sheetSelectName = name;
      } else if (lowerName.contains('apptype') || lowerName.contains('record') || lowerName.contains('ddl_app')) {
        applicationTypeSelectName = name;
      }
      
      // Skip disabled selects, as sending them triggers ASP.NET Event Validation errors
      if (s.attributes.containsKey('disabled')) continue;
      
      // Store default select values
      var options = s.querySelectorAll('option');
      var selectedOpt = options.where((o) => o.attributes.containsKey('selected')).firstOrNull;
      
      String val = '';
      if (selectedOpt != null) {
        val = selectedOpt.attributes['value'] ?? '';
      } else if (options.isNotEmpty) {
        val = options.first.attributes['value'] ?? '';
      }
      // Mimic Chrome: do not send unselected/empty child dropdowns!
      // In Urban, '00' is unselected. In Rural, '0' is unselected, but sometimes '0' is valid.
      // We will check if the text contains 'Select' to be safe.
      if (selectedOpt != null) {
        String optText = selectedOpt.text.toLowerCase();
        if (val.isNotEmpty && !optText.contains('select') && !optText.contains('પસંદ')) {
          _allInputs[name] = val;
        }
      } else if (val.isNotEmpty && val != '0' && val != '00') {
        _allInputs[name] = val;
      }
    }
    
    var captchaInput = document.querySelector('input[type="text"][id*="Captcha"], input[type="text"][id*="captcha"]');
    if (captchaInput != null) captchaInputName = captchaInput.attributes['name'] ?? '';
    
    var saveBtn = document.querySelector('input[type="submit"][id*="btnSave"], input[type="submit"][id*="btnFetch"], input[type="submit"][id*="btnGo"], input[type="submit"][id*="GetDetail"]');
    if (saveBtn != null) saveButtonName = saveBtn.attributes['name'] ?? '';
  }

  void _extractOptions(String htmlString) {
    var appTypes = _parseSelect(htmlString, applicationTypeSelectName);
    if (appTypes != null) applicationTypes = appTypes;

    var dists = _parseSelect(htmlString, districtSelectName);
    if (dists != null) districts = dists;

    var tals = _parseSelect(htmlString, talukaSelectName);
    if (tals != null) {
      talukas = tals;
      print('EXTRACTED ${tals.length} TALUKAS');
    } else {
      print('FAILED TO EXTRACT TALUKAS! Select name: $talukaSelectName');
    }
    
    var vils = _parseSelect(htmlString, villageSelectName);
    if (vils != null) villages = vils;

    var surs = _parseSelect(htmlString, surveySelectName);
    if (surs != null) surveyNumbers = surs;
    
    var shts = _parseSelect(htmlString, sheetSelectName);
    if (shts != null) sheets = shts;

    _extractRadios(htmlString);
  }

  void _extractRadios(String htmlString) {
    radioOptions.clear();
    var document = parser.parse(htmlString);
    var radios = document.querySelectorAll('input[type="radio"]');
    for (var radio in radios) {
      String name = radio.attributes['name'] ?? '';
      String id = radio.attributes['id'] ?? '';
      String value = radio.attributes['value'] ?? '';
      if (name.isNotEmpty && id.isNotEmpty) {
        radioGroupName = name; // Save the group name (e.g. ctl00$ContentPlaceHolder1$rdllist)
        
        // Find corresponding label
        var label = document.querySelector('label[for="$id"]');
        String text = label != null ? label.text.trim() : value;
        radioOptions.add({'value': value, 'text': text});
      }
    }
  }

  List<Map<String, String>>? _parseSelect(String htmlString, String selectName) {
    if (selectName.isEmpty) return null;
    
    // Find the select tag for the given name
    // It looks like <select name="ctl00$ContentPlaceHolder1$ddlTaluka" ...> ... </select>
    int startIdx = htmlString.indexOf('name="$selectName"');
    if (startIdx == -1) return null;
    
    int endIdx = htmlString.indexOf('</select>', startIdx);
    if (endIdx == -1) return null; // Or just search to the end of string
    
    String selectHtml = htmlString.substring(startIdx, endIdx);
    
    // Find all <option value="...">Text</option>
    RegExp optionRegExp = RegExp(r'<option[^>]*value="([^"]*)"[^>]*>(.*?)<\/option>', caseSensitive: false, dotAll: true);
    Iterable<Match> matches = optionRegExp.allMatches(selectHtml);
    
    List<Map<String, String>> result = [];
    for (var match in matches) {
      String val = match.group(1) ?? '';
      String text = match.group(2) ?? '';
      text = text.trim();
      // Remove any inner HTML tags from text just in case
      text = text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      
      if (val.trim().isNotEmpty && !text.toLowerCase().contains('select') && !text.contains('પસંદ')) {
        result.add({'value': val, 'text': text});
      }
    }
    
    // If we found the select but it had no valid options (e.g. only 'Select Taluka' with value '0'),
    // we still return [] to indicate it was parsed and is genuinely empty for this selection.
      return result;
  }

  Future<void> _loadCaptcha(String htmlString) async {
    var document = parser.parse(htmlString);
    var captchaImage = document.querySelector('img[id*="Captcha"], img[id*="captcha"], img[src*="Captcha"], img[src*="captcha"]');
    if (captchaImage != null) {
      String src = captchaImage.attributes['src'] ?? '';
      if (src.isNotEmpty) {
        if (src.startsWith('data:image')) {
          // Extract base64 part
          int commaIdx = src.indexOf(',');
          if (commaIdx != -1) {
            String b64 = src.substring(commaIdx + 1);
            try {
              captchaImageBytes = UriData.parse(src).contentAsBytes();
            } catch (e) {
              captchaImageBytes = base64Decode(b64);
            }
          }
        } else {
          String captchaUrl = src.startsWith('http') ? src : '$_baseUrl/$src';
          try {
            final response = await http.get(Uri.parse(captchaUrl), headers: _headers);
            if (response.statusCode == 200) {
              captchaImageBytes = response.bodyBytes;
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<String?> changeDropdown(String targetName, Map<String, String> currentSelections) async {
    try {
      Map<String, String> body = Map.from(_allInputs);
      body['__EVENTTARGET'] = targetName;
      body['__EVENTARGUMENT'] = '';
      
      // Add current selections
      body.addAll(currentSelections);

      print('--- STANDARD POST ---');
      print('Cookies: ${_headers["Cookie"]}');
      print('Target: $targetName');
      print('Selected Values: $currentSelections');
      
      final response = await http.post(
        Uri.parse(currentUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cache-Control': 'no-cache',
          'Origin': 'https://anyror.gujarat.gov.in',
          'Referer': currentUrl,
        },
        body: body,
      );

      print('Status Code: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        String bodySummary = body.entries.map((e) => '${e.key}=${e.value.length > 15 ? e.value.substring(0,15)+'...' : e.value}').join('\n');
        print('HTTP Error: ${response.statusCode}\nBody:\n$bodySummary\nHeaders:\n${response.headers}');
        return 'HTTP Error: ${response.statusCode}';
      }

      print('RESPONSE START: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      print('RESPONSE END: ${response.body.substring(response.body.length > 300 ? response.body.length - 300 : 0)}');

      if (response.body.contains('pageRedirect') || response.body.contains('CustomError.htm') || response.body.contains('Application Error')) {
        print('FAILED HTML HEAD: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');
        String snippet = response.body.length > 100 ? response.body.substring(0, 100) : response.body;
        
        String bodySummary = body.entries.map((e) => '${e.key}=${e.value.length > 15 ? e.value.substring(0,15)+'...' : e.value}').join('\n');
        
        return 'ASP.NET Error: $snippet\n\nCookies sent: ${_headers["Cookie"]}\nTarget: $targetName\n\nBody summary:\n$bodySummary';
      }

      _updateCookies(response);
      
      // Parse ASP.NET AJAX Delimited String
      if (response.body.contains('|hiddenField|__VIEWSTATE|')) {
        List<String> parts = response.body.split('|');
        for (int i = 0; i < parts.length; i++) {
          if (parts[i] == '__VIEWSTATE' && i + 1 < parts.length) {
            _viewState = parts[i + 1];
            _allInputs['__VIEWSTATE'] = _viewState;
          } else if (parts[i] == '__VIEWSTATEGENERATOR' && i + 1 < parts.length) {
            _viewStateGenerator = parts[i + 1];
            _allInputs['__VIEWSTATEGENERATOR'] = _viewStateGenerator;
          } else if (parts[i] == '__EVENTVALIDATION' && i + 1 < parts.length) {
            _eventValidation = parts[i + 1];
            _allInputs['__EVENTVALIDATION'] = _eventValidation;
          }
        }
      }

      // The delimited string also contains raw HTML snippets!
      // We can just feed the whole thing into our parser to extract updated dropdown options!
      _parseHtmlFields(response.body); // This will update _allInputs with the new HTML selects
      _extractOptions(response.body);
      await _loadCaptcha(response.body);
      
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> submitForm(Map<String, String> formSelections, String captchaText) async {
    try {
      _lastFormSelections = Map.from(formSelections);
      _lastCaptchaText = captchaText;
      
      Map<String, String> body = Map.from(_allInputs);
      body['__EVENTTARGET'] = '';
      body['__EVENTARGUMENT'] = '';
      body['__VIEWSTATE'] = _viewState;
      body['__VIEWSTATEGENERATOR'] = _viewStateGenerator;
      body['__EVENTVALIDATION'] = _eventValidation;
      
      body.addAll(formSelections);
      if (captchaInputName.isNotEmpty) {
        body[captchaInputName] = captchaText;
      }
      if (saveButtonName.isNotEmpty) {
        body[saveButtonName] = 'Get Record Detail'; // Fallback
      } else {
        print('!!! WARNING: saveButtonName IS EMPTY !!!');
      }

      print('--- SUBMIT POST ---');
      print('saveButtonName: $saveButtonName');
      print('captchaInputName: $captchaInputName');
      print('Selected Values: $formSelections');
      print('Exact Body Keys: ${body.keys.join(', ')}');
      
      // Let's print out if any required fields are missing
      List<String> required = [
        'ContentPlaceHolder1_ToolkitScriptManager1_HiddenField',
        '__LASTFOCUS',
        '__VIEWSTATEENCRYPTED'
      ];
      for (var r in required) {
        if (!body.containsKey(r)) {
          print('MISSING FROM BODY: $r (adding empty)');
          body[r] = '';
        }
      }

      var response = await http.post(
        Uri.parse(currentUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cache-Control': 'no-cache',
          'Origin': 'https://anyror.gujarat.gov.in',
          'Referer': currentUrl,
        },
        body: body,
      );

      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      
      // Handle ASP.NET Post/Redirect/Get pattern manually
      if (response.statusCode == 302) {
        String? location = response.headers['location'];
        if (location != null) {
          print('Redirecting manually to: $location');
          // Update cookies before following redirect!
          _updateCookies(response);
          String nextUrl = location.startsWith('http') ? location : 'https://anyror.gujarat.gov.in$location';
          
          response = await http.get(
            Uri.parse(nextUrl),
            headers: _headers, // includes cookies!
          );
          print('Redirect GET Status: ${response.statusCode}');
        }
      }

      String debugBody = response.body;
      if (debugBody.length > 300) debugBody = debugBody.substring(0, 300);
      print('Response Body snippet: $debugBody');

      if (response.statusCode != 200) {
        String snippet = response.body;
        if (snippet.length > 300) snippet = snippet.substring(0, 300);
        return 'Submit HTTP Error: ${response.statusCode} - $snippet';
      }

      print('SUBMIT RESPONSE START: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      _updateCookies(response);
      _parseHtmlFields(response.body);
      _viewState = _allInputs['__VIEWSTATE'] ?? _viewState;
      _viewStateGenerator = _allInputs['__VIEWSTATEGENERATOR'] ?? _viewStateGenerator;
      _eventValidation = _allInputs['__EVENTVALIDATION'] ?? _eventValidation;
      
      var document = parser.parse(response.body);
      
      // Try to extract the core result div
      var resultDiv = document.querySelector('div[id*="pnlResult"], div[id*="GridView"], table[class*="table"]');
      if (resultDiv != null) {
        return resultDiv.outerHtml;
      }
      
      var errorLabel = document.querySelector('span[id*="lblMsg"], span[id*="lblMessage"]');
      if (errorLabel != null && errorLabel.text.trim().isNotEmpty) {
        return "Error: ${errorLabel.text.trim()}";
      }

      // If we couldn't find a specific div, maybe just return the whole body as a fallback
      return "No results found or Invalid CAPTCHA.";
    } catch (e) {
      // Error on Submit
      return null;
    }
  }

  Future<Uint8List?> downloadPdf(String eventTarget, String eventArgument) async {
    try {
      Map<String, String> body = Map.from(_allInputs);
      body.addAll(_lastFormSelections);
      if (captchaInputName.isNotEmpty && _lastCaptchaText.isNotEmpty) {
        body[captchaInputName] = _lastCaptchaText;
      }
      
      body['__EVENTTARGET'] = eventTarget;
      body['__EVENTARGUMENT'] = eventArgument;
      body['__VIEWSTATE'] = _viewState;
      body['__VIEWSTATEGENERATOR'] = _viewStateGenerator;
      body['__EVENTVALIDATION'] = _eventValidation;
      
      // The browser actually does a Cross-Page PostBack to the Info page!
      String postbackUrl = currentUrl;
      if (currentUrl.toLowerCase().contains('landrecordrural')) {
        postbackUrl = 'https://anyror.gujarat.gov.in/Information_pages/InfoOld712Detail.aspx';
      } else if (currentUrl.toLowerCase().contains('landrecordurban') || currentUrl.toLowerCase().contains('generalreport_idb')) {
        postbackUrl = 'https://anyror.gujarat.gov.in/Information_pages/InfoPRCard.aspx';
      }

      var response = await http.post(
        Uri.parse(postbackUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cache-Control': 'no-cache',
          'Origin': 'https://anyror.gujarat.gov.in',
          'Referer': currentUrl,
        },
        body: body,
      );

      print('PDF Postback Status: ${response.statusCode}');
      
      // If server responds with direct PDF stream
      if (response.headers['content-type']?.toLowerCase().contains('pdf') == true) {
        return response.bodyBytes;
      }
      
      String? pdfUrl;
      // Handle ASP.NET redirect to PDF viewer page
      if (response.statusCode == 302) {
        pdfUrl = response.headers['location'];
      } else {
        // Print the first 1000 characters and any script tags for debugging
        print('PDF Postback Body (first 1000): ${response.body.length > 1000 ? response.body.substring(0, 1000) : response.body}');
        RegExp scriptsRegex = RegExp(r"<script[^>]*>(.*?)</script>", caseSensitive: false, dotAll: true);
        var scripts = scriptsRegex.allMatches(response.body);
        for (var s in scripts) {
          print('Found script: ${s.group(1)}');
        }
        
        RegExp modalRegex = RegExp(r'<div[^>]*id="myModal2"[^>]*>.*?</div>', caseSensitive: false, dotAll: true);
        var modalMatch = modalRegex.firstMatch(response.body);
        if (modalMatch != null) {
          print('FOUND MODAL2: ${modalMatch.group(0)?.substring(0, 500)}');
        }
        
        // Handle ASP.NET window.open script
        RegExp windowOpenRegex = RegExp(r"window\.open\(['""]([^'""]+)['""]");
        var match = windowOpenRegex.firstMatch(response.body);
        if (match != null) {
          pdfUrl = match.group(1);
        } else {
          // Sometimes ASP.NET emits a redirect script instead of window.open
          RegExp locationRegex = RegExp(r"window\.location(\.href)?\s*=\s*['""]([^'""]+)['""]");
          var locMatch = locationRegex.firstMatch(response.body);
          if (locMatch != null) {
            pdfUrl = locMatch.group(2);
          } else {
            // Search the entire raw HTML for the PDF viewer URL
            RegExp directUrlRegex = RegExp('["\']([^"\']+\\/(?:PDFView|DocumentViewer)[^"\']+)["\']', caseSensitive: false);
            var directMatch = directUrlRegex.firstMatch(response.body);
            if (directMatch != null) {
              pdfUrl = directMatch.group(1);
              print('Found PDF URL directly: $pdfUrl');
            } else {
              // Fallback to searching for ANY .aspx link with detail= parameter
              RegExp detailRegex = RegExp('["\']([^"\']+\\.aspx\\?detail=[^"\']+)["\']', caseSensitive: false);
              var detailMatch = detailRegex.firstMatch(response.body);
              if (detailMatch != null) {
                pdfUrl = detailMatch.group(1);
                print('Found detail URL: $pdfUrl');
              } else {
                // Try iframe as absolute last resort
                RegExp anyIframeRegex = RegExp('<(iframe|embed|object)[^>]+(?:src|data)\\s*=\\s*["\']([^"\']+)["\']', caseSensitive: false);
                var anyIframeMatch = anyIframeRegex.firstMatch(response.body);
                if (anyIframeMatch != null) {
                  pdfUrl = anyIframeMatch.group(2);
                  print('Found document inside iframe/embed/object: $pdfUrl');
                }
              }
            }
          }
        }
      }
      
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        pdfUrl = pdfUrl.replaceAll('&amp;', '&');
        print('Found Document URL: $pdfUrl');
        String nextUrl = pdfUrl.startsWith('http') ? pdfUrl : 'https://anyror.gujarat.gov.in/${pdfUrl.startsWith('/') ? pdfUrl.substring(1) : pdfUrl}';
        
        var pdfResponse = await http.get(
          Uri.parse(nextUrl),
          headers: _headers, // Use the same session cookies!
        );
        
        String contentType = pdfResponse.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.contains('pdf')) {
          return pdfResponse.bodyBytes;
        } else if (contentType.contains('image')) {
          print('Converting image to PDF...');
          final pdf = pw.Document();
          final image = pw.MemoryImage(pdfResponse.bodyBytes);
          pdf.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(image));
            }
          ));
          return await pdf.save();
        } else {
          print('Document URL returned invalid Content-Type: $contentType');
        }
      }

      return null;
    } catch (e) {
      print('PDF Download Error: $e');
      return null;
    }
  }
}
