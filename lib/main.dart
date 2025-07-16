import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: FileBrowser(), debugShowCheckedModeBanner: false);
  }
}

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  late Directory currentDirectory;
  List<FileSystemEntity> files = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    String homePath = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/';
    currentDirectory = Directory(homePath);
    loadDirectory();
  }

  Future<void> loadDirectory() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<FileSystemEntity> entities = await currentDirectory.list().toList();

      entities.sort((a, b) {
        bool aIsDir = a is Directory;
        bool bIsDir = b is Directory;

        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;

        return path.basename(a.path).toLowerCase().compareTo(path.basename(b.path).toLowerCase());
      });

      setState(() {
        files = entities;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        files = [];
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading directory: $e')));
      }
    }
  }

  void navigateToParent() {
    Directory? parent = currentDirectory.parent;
    if (parent.path != currentDirectory.path) {
      setState(() {
        currentDirectory = parent;
      });
      loadDirectory();
    }
  }

  void navigateToDirectory(Directory dir) {
    setState(() {
      currentDirectory = dir;
    });
    loadDirectory();
  }

  void selectFile(String path) {
    const videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    if (videoExtensions.any((ext) => path.toLowerCase().endsWith(ext))) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPage(path: path)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This file type may not be a playable video.')));
    }
  }

  Widget buildFileItem(FileSystemEntity entity) {
    bool isDirectory = entity is Directory;
    String fileName = path.basename(entity.path);

    return ListTile(
      leading: Icon(isDirectory ? Icons.folder : Icons.movie, color: isDirectory ? Colors.amber : Colors.blue),
      title: Text(fileName),
      subtitle: Text(isDirectory ? 'Directory' : 'File • ${_getFileSize(entity)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: isDirectory ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: () {
        if (isDirectory) {
          navigateToDirectory(entity as Directory);
        } else {
          selectFile(entity.path);
        }
      },
    );
  }

  String _getFileSize(FileSystemEntity entity) {
    try {
      if (entity is File) {
        int bytes = entity.lengthSync();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FVP File Browser'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.all(8),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: navigateToParent, tooltip: 'Go to parent directory'),
                Expanded(child: Text(currentDirectory.path, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : files.isEmpty
              ? Center(child: Text('Directory is empty or access denied', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  return buildFileItem(files[index]);
                },
              ),
    );
  }
}

class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.path});

  final String path;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Alignment> _positionAnimation;
  bool _isOverlayVisible = true;
  bool _isAudioEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));

    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      setState(() {});
      _controller.play();
      _controller.setLooping(true);
    });

    _animationController = AnimationController(duration: const Duration(seconds: 8), vsync: this)..repeat(reverse: true);
    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic);
    _positionAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(path.basename(widget.path)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isOverlayVisible ? Icons.visibility : Icons.visibility_off),
            tooltip: 'Toggle Test Overlay',
            onPressed: () {
              setState(() {
                _isOverlayVisible = !_isOverlayVisible;
              });
            },
          ),
          IconButton(
            icon: Icon(_isAudioEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: 'Toggle audio',
            onPressed: () {
              setState(() {
                _isAudioEnabled = !_isAudioEnabled;
              });
              _controller.setVolume(_isAudioEnabled ? 100 : 0);
            },
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized) {
              return Stack(
                children: [
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size?.width ?? 0,
                        height: _controller.value.size?.height ?? 0,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),

                  if (_isOverlayVisible)
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Align(alignment: _positionAnimation.value, child: ScaleTransition(scale: _scaleAnimation, child: child));
                      },
                      child: Container(
                        margin: const EdgeInsets.all(25),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepOrangeAccent.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
                        ),
                        child: const Text(
                          'Lag Test Overlay',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                ],
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          });
        },
        child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
