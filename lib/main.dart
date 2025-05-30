// ignore_for_file: library_private_types_in_public_api, non_constant_identifier_names, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_alarm_clock/flutter_alarm_clock.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobile Assistant',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Montserrat',
      ),
      home: const WelcomePage(),
    );
  }
}

// Welcome Page
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.deepPurple,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ai_image_2.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sahaayak welcomes you!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: "FontMain"),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AssistantPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 20,
                          fontFamily: "FontMain"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

// Assistant Page
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  _AssistantPageState createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final FlutterTts flutterTts = FlutterTts();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "Press the button and start speaking";
  final List<Map<String, Object>> _chatHistory = [];
  final TextEditingController _messageController = TextEditingController();
  final model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: 'AIzaSyDTxsmzNmraVKcS9l-J4-4EcbnSVY9HNeE',
  );

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _addToChat(String message, bool isUserMessage) {
    setState(() {
      _chatHistory.add({
        'message': message,
        'isUserMessage': isUserMessage,
      });
    });
  }

  Future<void> requestContactPermission() async {
    PermissionStatus permission = await Permission.contacts.status;
    if (!permission.isGranted) {
      await Permission.contacts.request();
    }
  }

  // Fetch contacts and call by name
  void callByName(String name) async {
    // Ensure we have the contact permission
    await requestContactPermission();

    Iterable<Contact> contacts =
        await ContactsService.getContacts(withThumbnails: false);

    String? phoneNumber;

    // Search for the contact by name
    for (var contact in contacts) {
      if (contact.displayName != null &&
          contact.displayName!.toLowerCase().contains(name.toLowerCase())) {
        if (contact.phones!.isNotEmpty) {
          phoneNumber = contact.phones!.first.value;
          break;
        }
      }
    }

    if (phoneNumber != null) {
      speak("Calling $name");
      FlutterPhoneDirectCaller.callNumber(phoneNumber);
      setState(() {
        _text = "Calling $name";
      });
    } else {
      speak("Sorry, I couldn't find a contact named $name");
      setState(() {
        _text = "Couldn't find a contact named $name";
      });
    }
  }

  // Voice input
  void _listen() async {
    await flutterTts.stop();
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);

        _speech.listen(
          onResult: (val) {
            // Continuously update the recognized words
            setState(() {
              _text = val.recognizedWords;
            });

            // When finalResult is true, the user has stopped speaking
            if (val.finalResult) {
              setState(() => _isListening = false); // Stop listening
              if (_text.isNotEmpty) {
                handleCommand(
                    _text.toLowerCase()); // Send full query to handleCommand
              }
            }
          },
          listenFor: const Duration(seconds: 100), // Set maximum listening time
          pauseFor:
              const Duration(seconds: 3), // Time to pause for final result
          partialResults: true, // Show partial results during listening
          onSoundLevelChange: (level) {}, // Optional: Monitor sound level
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop(); // Stop listening if already active
    }
  }

  // Functions to handle voice commands and map them to actions
  void handleCommand(String command) async {
    // Stop listening if a valid command is detected
    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
    }

    _addToChat(command, true); // User's command

    if (command.contains("flashlight on")) {
      speak("Turning on the flashlight");
      toggleFlashlight(true);
    } else if (command.contains("flashlight off")) {
      speak("Turning off the flashlight");
      toggleFlashlight(false);
    } else if (command.contains("volume")) {
      double? volumeChange = extractNumber(command);
      if (volumeChange != null) {
        adjustVolume(volumeChange);
      } else {
        speak("Please specify the volume change.");
      }
    } else if (command.contains("brightness")) {
      double? brightnessChange = extractNumber(command);
      if (brightnessChange != null) {
        adjustBrightness(brightnessChange);
      } else {
        speak("Please specify the brightness change.");
      }
    } else if (command.contains("open camera")) {
      openCameraApp();
    } else if (command.contains("call")) {
      String name = command.replaceAll("call", "").trim();
      callByName(name);
    } else if (command.contains("youtube")) {
      launchUrl("https://www.youtube.com" as Uri);
      speak("Opening YouTube");
    } else if (command.contains("google")) {
      launchUrl("https://www.google.com" as Uri);
      speak("Opening Google");
    } else if (command.contains("open")) {
      openApp(command);
    } else if (command.contains("alarm")) {
      setAlarmFromSpeech(command);
    } else if (command.contains("system")) {
      openSystemApp(command);
    } else {
      generateResponse(command);
    }
  }

  double? extractNumber(String command) {
    RegExp numberRegExp =
        RegExp(r'-?\d+'); // Matches positive and negative numbers
    Match? match = numberRegExp.firstMatch(command);
    if (match != null) {
      return double.parse(match.group(0)!);
    }
    return null;
  }

  void openCameraApp() async {
    // The package name for the default camera app can vary across different manufacturers
    // Some commonly used package names include:
    List<String> cameraPackages = [
      'com.android.camera',
      'com.sec.android.app.camera', // Samsung
      'com.google.android.GoogleCamera', // Google Pixel
      'com.lge.camera', // LG
      'com.huawei.camera', // Huawei
    ];

    bool cameraAppFound = false;

    // Check installed apps to find a camera app
    for (String packageName in cameraPackages) {
      bool isInstalled = await DeviceApps.isAppInstalled(packageName);
      if (isInstalled) {
        await DeviceApps.openApp(packageName);
        cameraAppFound = true;
        speak("Opening camera");
        setState(() {
          _text = "Opening camera";
        });
        break;
      }
    }

    // If no camera app found
    if (!cameraAppFound) {
      speak("Camera app not found on your device");
      setState(() {
        _text = "Camera app not found";
      });
    }
  }

  void generateResponse(String command) async {
    final prompt="Based on the situation provided, your task is to interpret it and determine the action that should be taken. Use the following guidelines to generate the correct output, ensuring you stick to the format strictly:\n\n1. **Turn On Flashlight:** If the situation implies turning on the flashlight, respond with:\n   - `#AD1DA#`\n\n2. **Call a Person:** If the situation suggests calling a specific person, respond with:\n   - `#AD2DA#:personName`\n   - Where \"personName\" is the name of the person interpreted from the situation.\n\n3. **Call a Phone Number:** If the situation implies calling a specific phone number, respond with:\n   - `#AD3DA#:phoneNumber`\n   - Where \"phoneNumber\" is the number interpreted from the situation.\n\n4. **Open a User Application:** If the situation suggests opening a specific app installed by the user, respond with:\n   - `#AD4DA#:applicationName`\n   - Where \"applicationName\" is the app name interpreted from the situation.\n\n5. **Open Camera:** If the situation suggests opening the camera, respond with:\n   - `#AD5DA#`\n\n6. **Change Volume:** If the situation implies adjusting the volume, respond with:\n   - `#AD6DA#:volumeDifference`\n   - Where \"volumeDifference\" is the change needed. Use a positive value for increasing volume and a negative value for decreasing it. The volume range is from 0 (lowest) to 5 (highest).\n\n7. **Change Brightness:** If the situation implies adjusting the screen brightness, respond with:\n   - `#AD7DA#:brightnessDifference`\n   - Where \"brightnessDifference\" is the change needed. Use a positive value for increasing brightness and a negative value for decreasing it. The brightness range is from 0 (lowest) to 5 (highest).\n\n8. **Set an Alarm:** If the situation suggests setting an alarm, respond with:\n   - `#AD8DA#:alarmTime`\n   - Where \"alarmTime\" is the time for the alarm interpreted from the situation.\n\n9. **Set a Timer:** If the situation suggests setting a timer, respond with:\n   - `#AD9DA#:timeDuration`\n   - Where \"timeDuration\" is the length of the timer interpreted from the situation.\n\n10. **Open a System Application:** If the situation suggests opening a system app (e.g., YouTube, Settings), respond with:\n   - `#AD10DA#:applicationName`\n   - Where \"applicationName\" is the app interpreted from the situation.\n\n### Additional Note:\nIf none of the above actions apply to the situation, handle it as a regular prompt and respond normally but dont copy the given command as it is give logical or factual answer to the question asked. Only respond according to the specified format if the situation matches one of the described actions. Avoid unnecessary explanations.\nSituaion:$command";
    final response = await model.generateContent([Content.text(prompt)]);
    // _addToChat(response.text!, false);
    // speak(response.text!);
     String? action = response.text?.trim();
  
  // Process the action based on the response
  if (action != null) {
    handleFormattedAction(action);
  } else {
    speak("Sorry, I didn't understand that.");
  }
  }

  void handleFormattedAction(String action) async {
  if (action.contains("#AD1DA#")) {
    // Turn flashlight on
    speak("Turning on the flashlight");
    toggleFlashlight(true);
  }
  else if (action.contains("#AD11DA#")) {
    // Turn flashlight off
    speak("Turning on the flashlight");
    toggleFlashlight(false);
  }
   else if (action.contains("#AD2DA#")) {
    // Call person
    String personName = action.substring("#AD2DA#:".length);
    speak("Calling $personName");
    //Here, you would need additional logic to retrieve the phone number for the person.
  } 
  else if (action.contains("#AD3DA#")) {
    // Call phone number
    String phoneNumber = action.substring("#AD3DA#:".length);
    
    if (phoneNumber.length==10||phoneNumber.length==9||phoneNumber.length==3) {
        speak("Calling $phoneNumber");
        makeCall(phoneNumber);
      } else {
        speak("Please provide a valid phone number.");
        setState(() {
          _text = "Please provide a valid phone number.";
        });
      }
  } else if (action.contains("#AD4DA#")) {
    // Open application
    String appName = action.substring("#AD4DA#:".length);
    openApp(appName);
  } else if (action == "#AD5DA#") {
    speak("Opening your camera App");
      openCameraApp();
  } else if (action.contains("#AD6DA#")) {
    // Adjust volume
    String volumeChange = action.substring("#AD6DA#:".length);
    double volumeDifference = double.parse(volumeChange);
    // Adjust volume logic
    speak("Adjusting volume by $volumeDifference");
    adjustVolume(volumeDifference);
  } else if (action.contains("#AD7DA#")) {
    // Adjust brightness
    String brightnessChange = action.substring("#AD7DA#:".length);
    double brightnessDifference = double.parse(brightnessChange);
    // Adjust brightness logic
    speak("Adjusting brightness by $brightnessDifference");
    adjustBrightness(brightnessDifference);
  } else if (action.contains("#AD8DA#")) {
    // Set alarm
    String alarmTime = action.substring("#AD8DA#:".length);
    setAlarmFromSpeech(alarmTime);
  } else if (action.contains("#AD9DA#")) {
    // Set timer
    String timerDuration = action.substring("#AD9DA#:".length);
    // Set timer logic
    speak("Setting timer for $timerDuration");
  } else if (action.contains("#AD10DA#")) {
    // Open system application
    String appName = action.substring("#AD10DA#:".length);
    openAppByPackageName(appName);
  } else {
    _addToChat(action, false);
    speak(action);
  }
}

  void adjustVolume(double delta) async {
    double currentVolume = await VolumeController()
        .getVolume(); // Get current volume (between 0.0 and 1.0)
    double newVolume = (currentVolume + delta / 100).clamp(
        0.0, 1.0); // Adjust the volume with delta and clamp between 0 and 1
    VolumeController().setVolume(newVolume); // Set new volume level

    // Feedback to user
    speak("Setting volume to ${(newVolume * 100).round()}%");
    setState(() {
      _text = "Volume set to ${(newVolume * 100).round()}%";
    });
  }

  // Adjust brightness by a specific delta (increase or decrease)
  void adjustBrightness(double delta) async {
    double currentBrightness = await ScreenBrightness()
        .current; // Get current brightness (between 0.0 and 1.0)
    double newBrightness = (currentBrightness + delta / 100).clamp(
        0.0, 1.0); // Adjust brightness with delta and clamp between 0 and 1
    await ScreenBrightness()
        .setScreenBrightness(newBrightness); // Set new brightness level

    // Feedback to user
    speak("Setting brightness to ${(newBrightness * 100).round()}%");
    setState(() {
      _text = "Brightness set to ${(newBrightness * 100).round()}%";
    });
  }

  // Function to toggle flashlight
  void toggleFlashlight(bool turnOn) async {
    try {
      if (turnOn) {
        await TorchLight.enableTorch();
        setState(() {
          _text = "Flashlight is ON";
        });
      } else {
        await TorchLight.disableTorch();
        setState(() {
          _text = "Flashlight is OFF";
        });
      }
    } catch (e) {
      setState(() {
        _text = "Error toggling flashlight";
      });
    }
  }

  // Function to extract phone number from command
  String? extractPhoneNumber(String command) {
    RegExp phoneRegExp = RegExp(r'\d+');
    Iterable<Match> matches = phoneRegExp.allMatches(command);

    if (matches.isNotEmpty) {
      return matches.first.group(0);
    }
    return null;
  }

  // Function to make a call
  void makeCall(String number) async {
    bool? res = await FlutterPhoneDirectCaller.callNumber(number);
    if (res!) {
      setState(() {
        _text = "Calling $number";
      });
    } else {
      setState(() {
        _text = "Failed to make a call";
      });
    }
  }

  // Function to open a website
  void openWebsite(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      speak("Could not open website");
      setState(() {
        _text = "Could not open website";
      });
    }
  }

  // Function to set an alarm using voice command
  void setAlarmFromSpeech(String command) {
    RegExp timeRegExp = RegExp(r'(\d+):(\d+)');
    Match? match = timeRegExp.firstMatch(command);

    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      setAlarm(hour, minute);
    } else {
      speak("Please provide a valid time in HH:MM format.");
      setState(() {
        _text = "Please provide a valid time in HH:MM format.";
      });
    }
  }

  // Function to set an alarm at a specific time
  void setAlarm(int hour, int minute) {
    FlutterAlarmClock.createAlarm(hour: hour, minutes: minute);
    speak("Setting alarm for $hour:$minute");
    setState(() {
      _text = "Alarm set for $hour:$minute";
    });
  }

  // Function to open a user-installed app
  void openApp(String command) async {
    String appName = command.replaceAll("open ", "").trim();
    List<Application> apps = await DeviceApps.getInstalledApplications();
    Application? targetApp;

    for (var app in apps) {
      if (app.appName.toLowerCase().contains(appName.toLowerCase())) {
        targetApp = app;
        break;
      }
    }

    if (targetApp != null) {
      DeviceApps.openApp(targetApp.packageName);
      speak("Opening $appName");
      setState(() {
        _text = "Opening $appName";
      });
    } else {
      speak("App not found: $appName");
      setState(() {
        _text = "App not found: $appName";
      });
    }
  }

  // Function to open system apps
  void openSystemApp(String command) {
    if (command.contains("contacts")) {
      openAppByPackageName('com.android.contacts');
    } else if (command.contains("calculator")) {
      openAppByPackageName('com.android.calculator2');
    } else if (command.contains("settings")) {
      openAppByPackageName('com.android.settings');
    } else if (command.contains("youtube")) {
      // Handle YouTube as a system or user-installed app
      openAppByPackageName('com.google.android.youtube');
    } else {
      speak("System app not found: $command");
      setState(() {
        _text = "System app not found: $command";
      });
    }
  }

  // Function to open app by package name
  void openAppByPackageName(String packageName) async {
    bool isOpened = await DeviceApps.openApp(packageName);
    if (isOpened) {
      speak("Opened system app.");
      setState(() {
        _text = "Opened system app.";
      });
    } else {
      speak("Could not open system app.");
      setState(() {
        _text = "Could not open system app.";
      });
    }
  }

  // Function to speak using text-to-speech
  Future<void> speak(String message) async {
    await flutterTts.speak(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sahaayak',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "FontMain"),
        ),
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 182, 255, 252),
            Color.fromARGB(255, 64, 242, 251)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ))),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final item = _chatHistory[index]; // Ensure type cast
                  final isUserMessage = item['isUserMessage'] as bool;
                  final message = item['message'] as String;

                  return ChatBubble(
                    message: message,
                    isUserMessage: isUserMessage,
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                onSubmitted: (value) {
                  //_addToChat(value, true); //chat User's message
                  handleCommand(value.toLowerCase());
                  _messageController.clear();
                },
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Type a message",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: _listen,
            backgroundColor: _isListening ? Colors.red : Colors.blueAccent,
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ChatBubble widget for displaying individual messages
  Widget ChatBubble({required String message, required bool isUserMessage}) {
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
        padding: const EdgeInsets.all(16.0),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUserMessage ? Colors.blueGrey : Colors.grey[800],
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
