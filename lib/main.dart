import 'dart:convert';

import 'package:aws_transcribe_api/transcribe-2017-10-26.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:minio_new/minio.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart' show Level;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      child: MainScreen(),
    ),
  );
}

const akey = String.fromEnvironment('awsAccessKey');
const skey = String.fromEnvironment('awsSecretKey');
const endPoint = String.fromEnvironment('endPoint');
const region = String.fromEnvironment('region');
const bucketName = String.fromEnvironment('bucketName');

final s3ServiceProvider = Provider((ref) {
  return Minio(
    region: region,
    accessKey: akey,
    secretKey: skey,
    endPoint: endPoint,
    useSSL: true,
  );
});

final transcribeServiceProvider = Provider((ref) {
  return TranscribeService(
    region: region,
    credentials: AwsClientCredentials(accessKey: akey, secretKey: skey),
  );
});

// final recorderProvider = Provider((ref) async {
//   final recorder = FlutterSoundRecorder(logLevel: Level.info);
//                     await recorder.openRecorder();
//                     if (!await recorder.isEncoderSupported(codec) && kIsWeb) {
//                       codec = Codec.opusWebM;
//                       mPath = 'speech.webm';
//                       if (!await recorder.isEncoderSupported(codec) && kIsWeb) {
//                         recorderInit = true;
//                       }
//                     }
//   return recorder;
// });

class MainScreen extends HookConsumerWidget {
  MainScreen({super.key});

  final theme = <int, String>{
    1: 'Words',
    2: 'Sentences',
  };

  final words = <int, String>{
    1: 'cat',
    2: 'mat',
    3: 'cap',
    4: 'map',
    5: 'man',
    6: 'big',
  };

  final sentences = <int, String>{
    1: "How are you?",
    2: "I’m fine, thank you.",
    3: "What’s that?",
    4: "It is your clock.",
    5: "Who is she?",
    6: "What’s your father’s name?",
  };

  final title = 'Speech to Text Demo';

  // FlutterSoundPlayer player = FlutterSoundPlayer();
  // bool playerInit = false;
  FlutterSoundRecorder recorder = FlutterSoundRecorder(logLevel: Level.info);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s3Service = ref.watch(s3ServiceProvider);
    final awsService = ref.watch(transcribeServiceProvider);

    final selectTheme = useState<int>(1);
    final selectedWord = useState<int>(1);
    final selectedSentence = useState<int>(1);
    final listening = useState<bool>(false);
    final recognizing = useState<bool>(false);
    final recorderInit = useState<bool>(true);
    final result = useState<String>('');

    String recordState = 'recording';

    useEffect(() {
      debugPrint('useEffect');
      return;
    }, [listening.value]);

    return MaterialApp(
      title: title,
      home: Scaffold(
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                RadioGroup(
                  theme,
                  groupValue: selectTheme,
                ),
                const Divider(color: Colors.black45),
                ScaledText(selectTheme.value == 1 ? '単語を選択してください。' : '文章を選択してください。'),
                selectTheme.value == 1
                    ? Container(
                        padding: EdgeInsets.all(20),
                        child: DropdownButton<String>(
                          dropdownColor: Colors.white,
                          value: words[selectedWord.value],
                          items: words.values
                              .map((e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: ScaledText(e, fontSize: 36.0),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            selectedWord.value = words.entries.firstWhere((element) => element.value == value).key;
                          },
                        ),
                      )
                    : Container(
                        padding: EdgeInsets.all(20),
                        child: DropdownButton<String>(
                          dropdownColor: Colors.white,
                          value: sentences[selectedSentence.value],
                          items: sentences.values
                              .map((e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: ScaledText(e, fontSize: 36.0),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            selectedSentence.value =
                                sentences.entries.firstWhere((element) => element.value == value).key;
                          },
                        ),
                      ),
                Visibility(
                  visible: result.value.isNotEmpty,
                  child: ScaledText(result.value),
                ),
                const Divider(color: Colors.black45),
                FilledButton.icon(
                  onPressed: () async {
                    if (listening.value) {
                      recordState = 'recording........';
                      return;
                    }
                    listening.value = true;

                    final objectName = const Uuid().v4();
                    //　録音開始
                    var codec = Codec.aacMP4;
                    var path = 'speech.mp4';
                    await recorder.openRecorder();
                    if (!await recorder.isEncoderSupported(codec)) {
                      codec = Codec.opusWebM;
                      path = 'speech.webm';
                      if (!await recorder.isEncoderSupported(codec)) {
                        recorderInit.value = false;
                        return;
                      }
                    }
                    try {
                      recorder.startRecorder(toFile: path, codec: codec).then(
                        (value) {},
                        onError: (e) {
                          debugPrint(e.toString());
                        },
                      );
                    } catch (e) {
                      recorderInit.value = false;
                      return;
                    }
                    while (recordState.length < 13) {
                      debugPrint(recordState);
                      recordState += '.';
                      await Future.delayed(const Duration(seconds: 1));
                    }
                    String? anURL = await recorder.stopRecorder();
                    recorder.closeRecorder();
                    // 再生テスト
                    // await player.openPlayer();
                    // await Future.delayed(Duration(seconds: 1));
                    // await player.startPlayer(
                    //     fromURI: _mPath,
                    //     whenFinished: () async {
                    //       await player.stopPlayer();
                    //       await player.closePlayer();
                    //     });

                    // 音声ファイルをS3にアップロード
                    if (anURL != null) {
                      recognizing.value = true;
                      final byteData = await http.readBytes(Uri.parse(anURL));
                      final stream = Stream<Uint8List>.value(byteData);
                      await s3Service.putObject(bucketName, 'audio/$objectName', stream);
                      // debugPrint(result.toString());

                      // アップロードしたファイルを音声認識処理
                      try {
                        await awsService.startTranscriptionJob(
                          media: Media(mediaFileUri: 'https://$endPoint/$bucketName/audio/$objectName'),
                          transcriptionJobName: objectName,
                          languageCode: LanguageCode.enUs,
                          outputBucketName: bucketName,
                          outputKey: "transcript/$objectName.json",
                        );
                      } on ConflictException catch (e) {
                        debugPrint(e.toString());
                      } on BadRequestException catch (e) {
                        debugPrint(e.toString());
                      } on LimitExceededException catch (e) {
                        debugPrint(e.toString());
                      } on InternalFailureException catch (e) {
                        debugPrint(e.toString());
                      } on Exception catch (e) {
                        debugPrint(e.toString());
                      }
                      await Future.delayed(const Duration(seconds: 2));

                      while (true) {
                        // 音声認識結果を取得
                        final response = await awsService.getTranscriptionJob(
                          transcriptionJobName: objectName,
                        );
                        if (response.transcriptionJob != null) {
                          final job = response.transcriptionJob!;
                          if (job.transcriptionJobStatus == TranscriptionJobStatus.completed) {
                            // debugPrint(job.transcript!.transcriptFileUri);
                            awsService.deleteTranscriptionJob(transcriptionJobName: objectName);
                            final jsonStream = (await s3Service.getObject(bucketName, "transcript/$objectName.json"))
                                .asBroadcastStream();
                            final Map<String, dynamic> jsonMap =
                                jsonDecode(await jsonStream.transform(utf8.decoder).join());
                            final Map<String, dynamic> results = jsonMap['results'];
                            final List<dynamic> transcripts = results['transcripts'];
                            if (transcripts.isNotEmpty) {
                              final Map<String, dynamic> transcript = transcripts[0];
                              result.value = transcript['transcript'].toString();
                              debugPrint(result.value);
                            }
                            recognizing.value = false;
                            break;
                          }
                        }
                        await Future.delayed(const Duration(seconds: 1));
                      }
                    }

                    listening.value = false;
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  icon: Icon(
                    listening.value ? Icons.mic_off : Icons.mic,
                    size: 32,
                  ),
                  label: ScaledText(
                    listening.value
                        ? recognizing.value
                            ? 'Recognizing...'
                            : 'Listening...'
                        : 'Tap to start.',
                    fontSize: 32.0,
                  ),
                ),
                Visibility(
                  visible: !recorderInit.value,
                  child: ScaledText(
                    'レコーダーの初期化に失敗しました。',
                  ),
                ),
                // Container(
                //   padding: EdgeInsets.all(10),
                //   child: FilledButton(
                //     child: Text(
                //       'Text to speech',
                //       style: TextStyle(fontSize: 20.0),
                //       textAlign: TextAlign.center,
                //     ),
                //     onPressed: () {},
                //   ),
                // ),
                // Center(
                //   child: RectangleWaveform(
                //     samples: [1, 23, 46, 78, 90, 12, 34, 56, 78],
                //     height: 100,
                //     width: 300,
                //     invert: true,
                //     // maxDuration: Duration(seconds: 10),
                //   ),
                // ),
                Visibility(
                  visible: false,
                  child: Wrap(
                    children: [
                      // ..._question.replaceAll('.', '').split(' ').mapIndexed((index, element) {
                      //   return Column(
                      //     children: [
                      //       Container(
                      //         padding: EdgeInsets.all(10),
                      //         child: Text(
                      //           element,
                      //           style: TextStyle(fontSize: 16.0),
                      //           textAlign: TextAlign.center,
                      //         ),
                      //       ),
                      //       Container(
                      //         padding: EdgeInsets.all(10),
                      //         child: Text(
                      //           _words.length > index ? _words[index] : '',
                      //           style: TextStyle(fontSize: 20.0, color: Colors.blue),
                      //           textAlign: TextAlign.center,
                      //         ),
                      //       ),
                      //       Container(
                      //         padding: EdgeInsets.all(10),
                      //         child: _words.length > index && _words[index] == element
                      //             ? Icon(Icons.circle_outlined, color: Colors.greenAccent.shade700)
                      //             : Icon(Icons.close_rounded, color: Colors.redAccent.shade700),
                      //       ),
                      //     ],
                      //   );
                      // }),①
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // floatingActionButton: FloatingActionButton(
        //   onPressed: () {},
        //   // If not yet listening for speech start, otherwise stop
        //   // _speechToText.isNotListening ? _startListening : _stopListening,
        //   tooltip: 'Listen',
        //   child: Icon(listening.value ? Icons.mic_off : Icons.mic),
        // ),
      ),
    );
  }
}

class ScaledText extends StatelessWidget {
  const ScaledText(
    this.text, {
    this.textAlign,
    this.overflow,
    this.softWrap = false,
    this.fontSize = 24,
    this.color,
    this.fontWeight,
    this.textHeight = 1.3,
    this.letterSpacing = 0.2,
    this.textScaleFactor = 1.0,
    this.textDecoration,
    this.maxLine,
    super.key,
  });
  final String text;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool softWrap;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  final double textHeight;
  final double letterSpacing;
  final double textScaleFactor;
  final TextDecoration? textDecoration;
  final int? maxLine;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLine ?? (softWrap ? null : 1),
      softWrap: softWrap,
      overflow: overflow,
      textAlign: textAlign,
      textScaleFactor: textScaleFactor,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: textHeight,
        letterSpacing: letterSpacing,
        decoration: textDecoration,
      ),
    );
  }
}

class RadioGroup<T> extends StatelessWidget {
  const RadioGroup(
    this.options, {
    required this.groupValue,
    this.fontSize = 32,
    this.on = Icons.radio_button_on,
    this.off = Icons.radio_button_off,
    this.forceVertical = false,
    super.key,
  });
  final Map<T, String> options;
  final ValueNotifier<T> groupValue;
  final double fontSize;
  final IconData on;
  final IconData off;
  final bool forceVertical;

  @override
  Widget build(BuildContext context) {
    var list = options.entries.map(
      (e) {
        final selected = e.key == groupValue.value;
        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 10,
          ),
          child: InkWell(
            onTap: () => groupValue.value = e.key,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    selected ? on : off,
                  ),
                ),
                ScaledText(
                  e.value,
                  fontSize: fontSize,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ],
            ),
          ),
        );
      },
    ).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: forceVertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: list,
            )
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: list,
            ),
    );
  }
}
