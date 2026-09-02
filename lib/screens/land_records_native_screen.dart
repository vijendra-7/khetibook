import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as parser;
import '../services/anyror_api_service.dart';
import '../providers/settings_provider.dart';
import 'pdf_viewer_screen.dart';
import 'land_unit_converter_screen.dart';
import 'ikhedut_web_view_screen.dart';
import 'all_offline_records_screen.dart';
import 'package:flutter/services.dart';

class LandRecordsNativeScreen extends StatefulWidget {
  final int? initialUrlIndex;
  
  const LandRecordsNativeScreen({super.key, this.initialUrlIndex});

  @override
  State<LandRecordsNativeScreen> createState() => _LandRecordsNativeScreenState();
}

class _LandRecordsNativeScreenState extends State<LandRecordsNativeScreen> {
  final AnyrorApiService _apiService = AnyrorApiService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _htmlResult;

  String? _selectedAppType;
  String? _selectedDistrict;
  String? _selectedTaluka;
  String? _selectedVillage;
  String? _selectedSheet;
  String? _selectedSurvey;
  String? _selectedRadio;
  
  int? _selectedUrlIndex; // null initially, 0 for Rural, 1 for Property
  final List<String> _urls = [
    'https://anyror.gujarat.gov.in/LandRecordRural.aspx',
    'https://anyror.gujarat.gov.in/emilkat/GeneralReport_IDB.aspx'
  ];
  
  List<String> _savedRecords = [];
  
  final TextEditingController _captchaController = TextEditingController();

  late final WebViewController _webViewController;

  bool get _isFormComplete {
    if (_isLoading) return false;
    if (_apiService.applicationTypes.isNotEmpty && _selectedAppType == null) return false;
    if (_apiService.districts.isNotEmpty && _selectedDistrict == null) return false;
    if (_apiService.talukas.isNotEmpty && _selectedTaluka == null) return false;
    if (_apiService.villages.isNotEmpty && _selectedVillage == null) return false;
    if (_apiService.sheets.isNotEmpty && _selectedSheet == null) return false;
    if (_apiService.surveyNumbers.isNotEmpty && _selectedSurvey == null) return false;
    if (_apiService.radioOptions.isNotEmpty && _selectedRadio == null) return false;
    
    // As an extra safeguard, make sure we actually have a survey dropdown available
    // because all AnyROR rural forms end with Survey/Block Number.
    if (_apiService.surveyNumbers.isEmpty) return false;
    
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedRecords();
    if (widget.initialUrlIndex != null) {
      _selectedUrlIndex = widget.initialUrlIndex;
      _initApi();
    }
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('FlutterChannel', onMessageReceived: (message) async {
        print('FLUTTER CHANNEL RECEIVED: ${message.message}');
        if (message.message.startsWith('POSTBACK|')) {
          var parts = message.message.split('|');
          if (parts.length >= 3) {
            String eventTarget = parts[1];
            String eventArgument = parts[2];
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading PDF...'), duration: Duration(seconds: 2)),
              );
            }
            
            Uint8List? pdfBytes = await _apiService.downloadPdf(eventTarget, eventArgument);
            if (pdfBytes != null) {
              // 1. Extract Survey Label
              String surveyLabel = '';
              try {
                surveyLabel = _apiService.surveyNumbers.firstWhere(
                  (e) => e['value'] == _selectedSurvey, 
                  orElse: () => {'text': ''}
                )['text'] ?? '';
              } catch (_) {}
              if (surveyLabel.isEmpty) surveyLabel = _selectedSurvey ?? '';

              // 2. Extract Year Range from HTML (e.g. 2000-2004)
              String yearRange = '';
              if (_htmlResult != null) {
                RegExp yearRegex = RegExp(r'\b(19\d{2}|20\d{2})\s*-\s*(19\d{2}|20\d{2})\b');
                var match = yearRegex.firstMatch(_htmlResult!);
                if (match != null) {
                  yearRange = ' (${match.group(1)}-${match.group(2)})';
                }
              }

              // 3. Format Title in Gujarati
              String rawTitle = surveyLabel.isNotEmpty 
                  ? 'સર્વે $surveyLabel$yearRange'
                  : 'સાચવેલા રેકોર્ડ્સ';
              
              String dynamicTitle = _toGujaratiDigits(rawTitle);

              final tempDir = await getTemporaryDirectory();
              // Use dynamic title for filename (replace slashes and spaces for valid filename)
              String validFilename = dynamicTitle.replaceAll('/', '_').replaceAll(' ', '_').replaceAll('(', '').replaceAll(')', '');
              final file = File('${tempDir.path}/$validFilename.pdf');
              await file.writeAsBytes(pdfBytes);
              
              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(
                      pdfPath: file.path,
                      title: dynamicTitle,
                    ),
                  ),
                );
                _loadSavedRecords(); // Refresh list when returning
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to download PDF.'), backgroundColor: Colors.red),
                );
              }
            }
          }
        }
      });
  }

  String _toGujaratiDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const gujarati = ['૦', '૧', '૨', '૩', '૪', '૫', '૬', '૭', '૮', '૯'];
    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], gujarati[i]);
    }
    return result;
  }

  Future<void> _loadSavedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedRecords = prefs.getStringList('saved_land_records') ?? [];
    });
  }

  Future<void> _initApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    if (_selectedUrlIndex == null) return;
    _apiService.setTargetUrl(_urls[_selectedUrlIndex!]);
    String? err = await _apiService.loadInitialPage();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (err != null) {
          _errorMessage = "Failed to load AnyROR portal: $err";
        }
        if (_apiService.radioOptions.isNotEmpty && _selectedRadio == null) {
          _selectedRadio = _apiService.radioOptions.first['value'];
        }
      });
    }
  }

  void _onUrlSwitched(int index) {
    setState(() {
      _selectedUrlIndex = index;
      _selectedAppType = null;
      _selectedDistrict = null;
      _selectedTaluka = null;
      _selectedVillage = null;
      _selectedSheet = null;
      _selectedSurvey = null;
      _selectedRadio = null;
      _captchaController.clear();
      _htmlResult = null;
    });
    _initApi();
  }

  Future<void> _onDropdownChanged(String targetName, String? newValue, void Function(String?) updateLocalState) async {
    if (newValue == null) return;
    
    setState(() {
      updateLocalState(newValue);
      _isLoading = true;
      _htmlResult = null; // Clear previous result
    });

    Map<String, String> currentSelections = {};
    if (_apiService.applicationTypeSelectName.isNotEmpty && _selectedAppType != null) {
      currentSelections[_apiService.applicationTypeSelectName] = _selectedAppType!;
    }
    if (_apiService.districtSelectName.isNotEmpty && _selectedDistrict != null) {
      currentSelections[_apiService.districtSelectName] = _selectedDistrict!;
    }
    if (_apiService.talukaSelectName.isNotEmpty && _selectedTaluka != null) {
      currentSelections[_apiService.talukaSelectName] = _selectedTaluka!;
    }
    if (_apiService.villageSelectName.isNotEmpty && _selectedVillage != null) {
      currentSelections[_apiService.villageSelectName] = _selectedVillage!;
    }
    if (_apiService.sheetSelectName.isNotEmpty && _selectedSheet != null) {
      currentSelections[_apiService.sheetSelectName] = _selectedSheet!;
    }
    if (_apiService.surveySelectName.isNotEmpty && _selectedSurvey != null) {
      currentSelections[_apiService.surveySelectName] = _selectedSurvey!;
    }
    if (_apiService.radioGroupName.isNotEmpty && _selectedRadio != null) {
      currentSelections[_apiService.radioGroupName] = _selectedRadio!;
    }
    
    String? error = await _apiService.changeDropdown(targetName, currentSelections);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (error != null) {
          print('!!! DROPDOWN ERROR: $error !!!');
          _errorMessage = 'Failed: $error';
        } else {
          _errorMessage = null;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_captchaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the CAPTCHA')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    Map<String, String> formSelections = {};
    if (_apiService.applicationTypeSelectName.isNotEmpty) {
      formSelections[_apiService.applicationTypeSelectName] = _selectedAppType ?? '0';
    }
    if (_apiService.districtSelectName.isNotEmpty) {
      formSelections[_apiService.districtSelectName] = _selectedDistrict ?? '0';
    }
    if (_apiService.talukaSelectName.isNotEmpty) {
      formSelections[_apiService.talukaSelectName] = _selectedTaluka ?? '0';
    }
    if (_apiService.villageSelectName.isNotEmpty) {
      formSelections[_apiService.villageSelectName] = _selectedVillage ?? '0';
    }
    if (_apiService.sheetSelectName.isNotEmpty) {
      formSelections[_apiService.sheetSelectName] = _selectedSheet ?? '0';
    }
    if (_apiService.surveySelectName.isNotEmpty) {
      formSelections[_apiService.surveySelectName] = _selectedSurvey ?? '0';
    }
    if (_apiService.radioGroupName.isNotEmpty && _selectedRadio != null) {
      formSelections[_apiService.radioGroupName] = _selectedRadio!;
    }

    String? result = await _apiService.submitForm(formSelections, _captchaController.text.trim());

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (result == null) {
          _errorMessage = "Failed to fetch records. Please try again.";
        } else if (result.startsWith("Error:")) {
          _errorMessage = result;
        } else {
          bool gu = Provider.of<SettingsProvider>(context, listen: false).isGujarati;
          _htmlResult = _wrapHtmlWithStyling(result, gu);
          _webViewController.loadHtmlString(_htmlResult!);
        }
      });
    }
  }

  String _wrapHtmlWithStyling(String bodyHtml, bool gu) {
    final titleText = gu ? 'જમીન ના ઉતારા' : 'Land Record Details';
    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { font-family: system-ui, -apple-system, sans-serif; padding: 12px; margin: 0; background-color: #F4F7F4; color: #333; }
          .title { color: #1B5E20; font-size: 20px; font-weight: 800; margin-bottom: 16px; text-align: center; }
          
          /* Desktop layout */
          table { width: 100%; border-collapse: separate; border-spacing: 0; margin-top: 10px; background-color: white; box-shadow: 0 4px 12px rgba(0,0,0,0.05); border-radius: 12px; overflow: hidden; }
          th, td { border-bottom: 1px solid #f0f0f0; padding: 14px 16px; text-align: left; font-size: 15px; }
          th { background-color: #1B5E20; color: white; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; font-size: 13px; position: sticky; top: 0; z-index: 10; border-bottom: none; }
          tr:last-child td { border-bottom: none; }
          tr:nth-child(even) { background-color: #fafafa; }
          
          /* Mobile layout (Advanced Premium Cards) */
          @media screen and (max-width: 600px) {
            table { border: 0; box-shadow: none; background: transparent; border-radius: 0; }
            table thead, .mobile-hide-header-row { display: none !important; }
            table tr { 
              display: block; 
              margin-bottom: 16px; 
              background-color: white; 
              border-radius: 16px; 
              box-shadow: 0 4px 15px rgba(0,0,0,0.06); 
              padding: 16px; 
              border: 1px solid rgba(0,0,0,0.04);
            }
            table td { 
              display: flex; 
              flex-direction: column;
              border-bottom: 1px solid #f0f0f0; 
              font-size: 16px; 
              text-align: left; 
              padding: 12px 4px;
              color: #111;
              font-weight: 700;
            }
            table td::before { 
              content: attr(data-label); 
              font-size: 12px;
              font-weight: 600; 
              color: #666; 
              margin-bottom: 6px;
              text-transform: uppercase;
              letter-spacing: 0.3px;
            }
            table td:last-child { border-bottom: 0; padding-bottom: 4px; }
            tr:nth-child(even) { background-color: white; }
            
            /* View PDF Button Polish */
            table td a {
              display: block;
              text-align: center;
              background: linear-gradient(135deg, #2E7D32 0%, #1B5E20 100%);
              color: white !important;
              padding: 14px;
              border-radius: 24px;
              text-decoration: none;
              font-weight: bold;
              font-size: 15px;
              margin-top: 10px;
              box-shadow: 0 4px 10px rgba(27, 94, 32, 0.3);
              transition: all 0.2s ease;
            }
            table td a:active {
              transform: scale(0.98);
            }
          }
        </style>
        <script>
          document.addEventListener('DOMContentLoaded', function() {
             var links = document.querySelectorAll('a');
             for (var i = 0; i < links.length; i++) {
                // Translate 'View PDF' to Gujarati
                if (links[i].innerText.trim().toLowerCase() === 'view pdf') {
                    links[i].innerText = 'પીડીએફ જુઓ';
                }
                
                links[i].addEventListener('click', function(e) {
                   e.preventDefault();
                   var href = this.getAttribute('href');
                   if (href) {
                      if (href.indexOf('javascript:__doPostBack') === 0) {
                         var match = href.match(/'([^']*)','([^']*)'/);
                         if (match) {
                            FlutterChannel.postMessage('POSTBACK|' + match[1] + '|' + match[2]);
                         } else {
                            FlutterChannel.postMessage('POSTBACK_RAW|' + href);
                         }
                      } else {
                         FlutterChannel.postMessage('LINK|' + href);
                      }
                   } else {
                     FlutterChannel.postMessage('NOHREF|' + this.innerHTML);
                   }
                });
             }
             
             // Mobile-friendly data-labels
             var tables = document.querySelectorAll('table');
             tables.forEach(function(table) {
                 var rows = table.querySelectorAll('tr');
                 var headers = table.querySelectorAll('th');
                 
                 if (headers.length > 0) {
                     // Hide the actual row containing the headers on mobile!
                     for(var r=0; r<rows.length; r++) {
                         if(rows[r].querySelector('th')) {
                             rows[r].classList.add('mobile-hide-header-row');
                         }
                     }
                     
                     for (var i = 1; i < rows.length; i++) {
                         var cells = rows[i].querySelectorAll('td');
                         for (var j = 0; j < cells.length && j < headers.length; j++) {
                             cells[j].setAttribute('data-label', headers[j].innerText.trim());
                         }
                     }
                 } else if (rows.length > 1) {
                     var firstRowCells = rows[0].querySelectorAll('td');
                     var hasActualData = false;
                     // Heuristic to check if first row is actually a header
                     if (firstRowCells.length > 1) {
                       for (var i = 1; i < rows.length; i++) {
                           var cells = rows[i].querySelectorAll('td');
                           for (var j = 0; j < cells.length && j < firstRowCells.length; j++) {
                               cells[j].setAttribute('data-label', firstRowCells[j].innerText.trim());
                           }
                       }
                       rows[0].classList.add('mobile-hide-header-row');
                     }
                 }
             });
          });
        </script>
      </head>
      <body>
        <div class="title">$titleText</div>
        $bodyHtml
      </body>
      </html>
    """;
  }

  Widget _buildDropdown(String label, String? value, List<Map<String, String>> options, void Function(String?) onChanged, {bool gu = false}) {
    bool isEnabled = options.isNotEmpty;
    
    // Ensure the selected value exists in the options, otherwise reset it
    if (value != null && !options.any((opt) => opt['value'] == value)) {
      value = null;
    }

    String hintText;
    if (isEnabled) {
      hintText = 'Select $label';
    } else if (_isLoading) {
      hintText = gu ? 'લોડ થઈ રહ્યું છે...' : 'Loading...';
    } else {
      hintText = gu ? 'ઉપલબ્ધ નથી' : 'Not available';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: isEnabled ? Colors.white : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: isEnabled
                ? const Icon(Icons.arrow_drop_down)
                : (_isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E20)),
                      )
                    : const Icon(Icons.arrow_drop_down, color: Colors.grey)),
            items: options.map((opt) {
              String displayText = opt['text']!;
              if (gu) {
                // Swap "English (Gujarati)" to "Gujarati (English)"
                final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(displayText);
                if (match != null) {
                  String eng = match.group(1)!.trim();
                  String guj = match.group(2)!.trim();
                  displayText = '$guj ($eng)';
                }
              }
              return DropdownMenuItem<String>(
                value: opt['value'],
                child: Text(displayText, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: isEnabled ? onChanged : null,
            hint: Text(hintText),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.select<SettingsProvider, bool>((p) => p.isGujarati);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: true,
        leading: widget.initialUrlIndex != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (_htmlResult != null) {
                  // If viewing result, go back to form
                  setState(() {
                    _htmlResult = null;
                  });
                } else {
                  // If viewing form, pop screen
                  Navigator.of(context).pop();
                }
              },
            )
          : null,
        title: Text(
          gu ? '૭/૧૨ અને ૮-અ' : '7/12 & 8A',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surfaceContainerLowest,
        foregroundColor: cs.onSurface,
        actions: [
          if (_selectedUrlIndex != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _initApi,
              tooltip: 'Refresh Session',
            ),
        ],
      ),
      body: Stack(
        children: [
          _selectedUrlIndex == null
              ? _buildSelectionView(gu)
              : (_isLoading && _apiService.districts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _htmlResult != null
                      ? _buildResultView()
                      : _buildFormView(gu)),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF1B5E20)),
                        const SizedBox(height: 16),
                        Text(
                          gu ? 'અધિકૃત રેકોર્ડ મેળવી રહ્યા છીએ...' : 'Fetching Official Records...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gu ? 'કૃપા કરીને રાહ જુઓ' : 'Please wait',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionView(bool gu) {
    return Container(
      color: const Color(0xFFF4F7F4),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, 
                height: 24, 
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(4),
                )
              ),
              const SizedBox(width: 12),
              Text(
                gu ? 'જમીન રેકોર્ડ' : 'Land Records',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20)),
              ),
              const Spacer(),
              Icon(Icons.dashboard_customize_rounded, color: Colors.green.shade700, size: 28),
            ],
          ),
          const SizedBox(height: 24),
          
          // Full Width Rural Banner Card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LandRecordsNativeScreen(initialUrlIndex: 0),
                ),
              ).then((_) => _loadSavedRecords());
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, const Color(0xFF1B5E20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gu ? 'જમીન રેકોર્ડ (ગ્રામીણ)' : 'Land Records (Rural)',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gu ? 'ગ્રામીણ વિસ્તારના ૭/૧૨, ૮-અ અને અન્ય દસ્તાવેજો મેળવો' : 'View 7/12, 8A and mutation records for villages',
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          
          if (_savedRecords.isNotEmpty) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Container(
                  width: 4, 
                  height: 24, 
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(4),
                  )
                ),
                const SizedBox(width: 12),
                Text(
                  gu ? 'સાચવેલા ઓફલાઇન રેકોર્ડ્સ' : 'Saved Offline Records',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20)),
                ),
                const Spacer(),
                Icon(Icons.folder_copy_rounded, color: Colors.green.shade700, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedRecords.length > 2 ? 3 : _savedRecords.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                // "View All" Button at the end of the list
                if (_savedRecords.length > 2 && index == 2) {
                  return TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AllOfflineRecordsScreen()),
                      ).then((_) => _loadSavedRecords());
                    },
                    icon: Icon(Icons.open_in_new_rounded, color: Colors.green.shade800, size: 20),
                    label: Text(
                      gu ? 'બધા ${_savedRecords.length} રેકોર્ડ્સ જુઓ' : 'View All ${_savedRecords.length} Records',
                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.green.shade50,
                    ),
                  );
                }

                final record = _savedRecords[index];
                  final parts = record.split('|');
                  if (parts.length < 3) return const SizedBox.shrink();
                  
                  final path = parts[0];
                  final title = parts[1];
                  final date = DateTime.tryParse(parts[2]);
                  final dateString = date != null ? '${date.day}/${date.month}/${date.year}' : '';

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade400),
                      ),
                      title: Text(
                        title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(dateString, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300),
                        onPressed: () async {
                          final file = File(path);
                          if (await file.exists()) {
                            await file.delete();
                          }
                          setState(() {
                            _savedRecords.removeAt(index);
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList('saved_land_records', _savedRecords);
                        },
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(
                              pdfPath: path,
                              title: title,
                              isOfflineRecord: true,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
          
          const SizedBox(height: 16),
          const Divider(color: Colors.black12, thickness: 1, indent: 24, endIndent: 24),
          // iKhedut Subsidy Banner hidden for now
          // Land Unit Converter Banner
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LandUnitConverterScreen()));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF558B2F), Color(0xFF33691E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF33691E).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calculate_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gu ? 'જમીન માપણી કેલ્ક્યુલેટર' : 'Land Unit Converter',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gu ? 'વીઘા, એકર, ગુંઠા, હેક્ટરની ગણતરી' : 'Convert Vigha, Acre, Guntha, Hectare',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Disclaimer: This is an unofficial app and is not affiliated with, endorsed by, or connected to any government entity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildResultView() {
    return WebViewWidget(controller: _webViewController);
  }

  Widget _buildFormView(bool gu) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
            
          const Text(
            'Gujarat Land Records Portal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (_apiService.radioOptions.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: _apiService.radioOptions.map((radio) {
                  bool isSelected = _selectedRadio == radio['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isSelected) {
                          _onDropdownChanged(_apiService.radioGroupName, radio['value'], (v) => _selectedRadio = v);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Text(
                          radio['text']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (_apiService.applicationTypes.isNotEmpty)
            _buildDropdown(
              _selectedUrlIndex == 1 ? (gu ? 'કોઈ એક પસંદ કરો' : 'Select any one') : (gu ? 'અરજીનો પ્રકાર (Application Type)' : 'Application Type'),
              _selectedAppType,
              _apiService.applicationTypes,
              (val) => _onDropdownChanged(_apiService.applicationTypeSelectName, val, (v) => _selectedAppType = v),
              gu: gu,
            ),

          
          if (_apiService.districts.isNotEmpty)
            _buildDropdown(
              gu ? 'જિલ્લો (District)' : 'District',
              _selectedDistrict,
              _apiService.districts,
              (val) => _onDropdownChanged(_apiService.districtSelectName, val, (v) => _selectedDistrict = v),
              gu: gu,
            ),

          if (_apiService.talukas.isNotEmpty || _selectedDistrict != null)
            _buildDropdown(
              _selectedUrlIndex == 1 ? (gu ? 'સીટી સરવે ઓફીસ (City Survey Office)' : 'City Survey Office') : (gu ? 'તાલુકો (Taluka)' : 'Taluka'),
              _selectedTaluka,
              _apiService.talukas,
              (val) => _onDropdownChanged(_apiService.talukaSelectName, val, (v) => _selectedTaluka = v),
              gu: gu,
            ),

          if (_apiService.villages.isNotEmpty || _selectedTaluka != null)
            _buildDropdown(
              _selectedUrlIndex == 1 ? (gu ? 'વોર્ડ (Ward)' : 'Ward') : (gu ? 'ગામ (Village)' : 'Village'),
              _selectedVillage,
              _apiService.villages,
              (val) => _onDropdownChanged(_apiService.villageSelectName, val, (v) => _selectedVillage = v),
              gu: gu,
            ),

          if (_apiService.surveyNumbers.isNotEmpty || _selectedVillage != null)
             _buildDropdown(
              _selectedUrlIndex == 1 ? (gu ? 'સરવે નંબર (City Survey No)' : 'City Survey No') : (gu ? 'સર્વે નંબર (Survey/Block No)' : 'Survey/Block No'),
              _selectedSurvey,
              _apiService.surveyNumbers,
              (val) {
                 setState(() {
                   _selectedSurvey = val;
                 });
                 _onDropdownChanged(_apiService.surveySelectName, val, (v) => _selectedSurvey = v);
              },
              gu: gu,
            ),

          if (_apiService.sheets.isNotEmpty || (_selectedUrlIndex == 1 && _selectedSurvey != null))
            _buildDropdown(
              gu ? 'શીટ નંબર (Sheet No)' : 'Sheet No',
              _selectedSheet,
              _apiService.sheets,
              (val) => _onDropdownChanged(_apiService.sheetSelectName, val, (v) => _selectedSheet = v),
              gu: gu,
            ),

          const SizedBox(height: 10),
          
          if (_isFormComplete && _apiService.captchaImageBytes != null)
            Card(
              elevation: 0,
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(12)
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('કેપ્ચા દાખલ કરો', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1B5E20))),
                    const SizedBox(height: 12),
                    Container(
                      height: 60,
                      width: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: Image.memory(
                        _apiService.captchaImageBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('જે આંકડા ઉપર દેખાય એ દાખલ કરો', style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _captchaController,
                      decoration: InputDecoration(
                        labelText: 'Captcha / કેપ્ચા',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
          
          if (_isLoading && _apiService.districts.isNotEmpty)
             const Center(child: CircularProgressIndicator())
          else if (_isFormComplete)
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(gu ? 'વિગતો જુઓ' : 'View Details', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
