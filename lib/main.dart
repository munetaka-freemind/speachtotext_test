import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  List<String> _words = [];
  final _questions = [
    '''I like swimming. I'm good at it.''',
    '''Let's drink some water.''',
    'My English class begins at eight thirty.',
    'I have a lot of homework to do.',
    'I want to buy a birthday present for my mother.',
    'A hamburger in this picture looks real.',
  ];
  String _question = '''I like swimming. I'm good at it.''';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    _lastWords = '';
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenMode: ListenMode.search,
      listenFor: Duration(seconds: 15),
      localeId: 'en_US',
    );
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    _words = result.recognizedWords.split(' ');
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech Demo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(10),
                child: Text(
                  '例題:',
                  style: TextStyle(fontSize: 20.0),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: EdgeInsets.all(10),
                child: DropdownButton<String>(
                  value: _question,
                  items: _questions
                      .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(fontSize: 14.0),
                              textAlign: TextAlign.center,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    _lastWords = '';
                    setState(() {
                      _question = value!;
                    });
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(10),
                child: FilledButton(
                  child: Text(
                    'Text to speech',
                    style: TextStyle(fontSize: 20.0),
                    textAlign: TextAlign.center,
                  ),
                  onPressed: () {
                    final tts = FlutterTts();
                    tts.setLanguage('en-US');
                    tts.speak(_question);
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(10),
                child: Text(
                  '''Recognized words:
              $_lastWords''',
                  style: TextStyle(fontSize: 20.0),
                  textAlign: TextAlign.center,
                ),
              ),
              Visibility(
                visible: _lastWords.isNotEmpty,
                child: Column(
                  children: [
                    const Divider(color: Colors.black45),
                    Wrap(
                      children: [
                        ..._question.replaceAll('.', '').split(' ').mapIndexed((index, element) {
                          return Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                child: Text(
                                  element,
                                  style: TextStyle(fontSize: 16.0),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(10),
                                child: Text(
                                  _words.length > index ? _words[index] : '',
                                  style: TextStyle(fontSize: 20.0, color: Colors.blue),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(10),
                                child: _words.length > index && _words[index] == element
                                    ? Icon(Icons.circle_outlined, color: Colors.greenAccent.shade700)
                                    : Icon(Icons.close_rounded, color: Colors.redAccent.shade700),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.black45),
              Container(
                padding: EdgeInsets.all(10),
                child: Text(
                  // If listening is active show the recognized words
                  _speechToText.isListening
                      ? 'Now listening...'
                      // If listening isn't active but could be tell the user
                      // how to start it, otherwise indicate that speech
                      // recognition is not yet ready or not supported on
                      // the target device
                      : _speechEnabled
                          ? 'Tap the microphone to start listening...'
                          : 'Speech not available',
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            // If not yet listening for speech start, otherwise stop
            _speechToText.isNotListening ? _startListening : _stopListening,
        tooltip: 'Listen',
        child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}
