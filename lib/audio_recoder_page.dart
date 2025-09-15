import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  State<AudioRecorderPage> createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  final _recorder = AudioRecorder(); // v5
  final _player = AudioPlayer();

  String? _filePath;
  bool _isRecording = false;

  // Timer
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  // Playback progress
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  List<FileSystemEntity> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) => f.path.endsWith('.m4a')).toList();
    setState(() {
      _recordings = files;
    });
  }

  /// Start recording
  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = "recording_${DateTime.now().millisecondsSinceEpoch}.m4a";
      final filePath = p.join(dir.path, fileName);

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _filePath = filePath;
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordDuration += const Duration(seconds: 1);
        });
      });
    }
  }

  /// Stop recording
  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    _recordTimer?.cancel();

    setState(() {
      _filePath = path;
      _isRecording = false;
    });
    _loadRecordings();
  }

  /// Play a recording
  Future<void> _playRecording(String? path) async {
    if (path != null && File(path).existsSync()) {
      try {
        await _player.setFilePath(path);

        // Listen to position changes
        _player.positionStream.listen((position) {
          setState(() {
            _playbackPosition = position;
          });
        });

        // Listen to duration
        _player.durationStream.listen((duration) {
          setState(() {
            _playbackDuration = duration ?? Duration.zero;
          });
        });

        await _player.play();
      } catch (e) {
        print("Error playing audio: $e");
      }
    }
  }

  /// Delete single recording
  Future<void> _deleteRecording(FileSystemEntity file) async {
    await file.delete();
    _loadRecordings();
  }

  /// Delete all recordings
  Future<void> _deleteAllRecordings() async {
    for (var file in _recordings) {
      await file.delete();
    }
    _loadRecordings();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    return d.toString().split('.').first.substring(2, 7);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audio Recorder"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _recordings.isEmpty ? null : _deleteAllRecordings,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Recording timer
          if (_isRecording)
            Text(
              _formatDuration(_recordDuration),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 10),

          // Playback progress bar
          if (_playbackDuration > Duration.zero)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Slider(
                    min: 0,
                    max: _playbackDuration.inSeconds.toDouble(),
                    value: _playbackPosition.inSeconds
                        .toDouble()
                        .clamp(0, _playbackDuration.inSeconds.toDouble()),
                    onChanged: (value) async {
                      await _player.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                  Text(
                    "${_formatDuration(_playbackPosition)} / ${_formatDuration(_playbackDuration)}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _recordings.isEmpty
                ? const Center(child: Text("No recordings yet"))
                : ListView.builder(
                    itemCount: _recordings.length,
                    itemBuilder: (context, index) {
                      final file = _recordings[index];
                      final fileName = p.basename(file.path);
                      return ListTile(
                        leading: const Icon(Icons.audiotrack),
                        title: Text(fileName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _playRecording(file.path),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteRecording(file),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          // Circular record button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
