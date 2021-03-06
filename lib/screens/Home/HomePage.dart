import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:tiktok_clone/main.dart';
import 'package:tiktok_clone/screens/Home/Overlay.dart';
import 'package:tiktok_clone/Utils/FireAuth.dart';
import 'package:tiktok_clone/Utils/FireDB.dart';
import 'package:tiktok_clone/Utils/FireStorage.dart';

class HomePage extends StatefulWidget {
  HomePage({
    this.videoPlayerController,
    this.initVideoPlayerController,
    this.setVideoPlayerController,
    this.startPlaying,
  });

  final VideoPlayerController videoPlayerController;
  final Future initVideoPlayerController;
  final Function setVideoPlayerController;
  final Function startPlaying;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<QueryDocumentSnapshot> _videos;
  int _pageIndex = 0;
  bool _liked = false;

  void _setIndex(int index) {
    setState(() {
      _pageIndex = index;
      if (auth.isSignedIn) {
        if (_videos[_pageIndex].data()['likedBy'].contains(fireDB.id))
          _liked = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _videos = snapshot.data.docs;
          if (_videos.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              TikToksView(
                setIndex: _setIndex,
                videos: _videos.map((documentSnapshot) {
                  return documentSnapshot.data()['path'];
                }).toList(),
                videoPlayerController: widget.videoPlayerController,
                setVideoPlayerController: widget.setVideoPlayerController,
                startPlaying: widget.startPlaying,
                initVideoPlayerController: widget.initVideoPlayerController,
              ),
              VideosOverlay(
                username:
                    fireDB.getUsername(_videos[_pageIndex].data()['creator']),
                description: _videos[_pageIndex].data()['description'],
                likes: _videos[_pageIndex].data()['likes'],
                liked: _liked,
                addLike: () {
                  if (auth.isSignedIn) {
                    if (_liked) {
                      _videos[_pageIndex]
                          .data()
                          .update('likes', (value) => value - 1);
                      _videos[_pageIndex].data().update(
                          'likedBy', (value) => value.remove(fireDB.id));
                      setState(() {
                        _liked = true;
                      });
                    } else {
                      _videos[_pageIndex]
                          .data()
                          .update('likes', (value) => value + 1);
                      _videos[_pageIndex]
                          .data()
                          .update('likedBy', (value) => value.add(fireDB.id));
                      setState(() {
                        _liked = true;
                      });
                    }
                  } else {
                    showSignInModalSheet(context);
                  }
                },
              ),
            ],
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
      stream: fireDB.getUploadsStream(),
    );
  }
}

class TikToksView extends StatefulWidget {
  TikToksView({
    this.setIndex,
    this.videos,
    this.initVideoPlayerController,
    this.videoPlayerController,
    this.setVideoPlayerController,
    this.startPlaying,
  });

  final Function setIndex;
  final List videos;
  VideoPlayerController videoPlayerController;
  Future initVideoPlayerController;
  final Function setVideoPlayerController;
  final Function startPlaying;

  @override
  _TikToksViewState createState() => _TikToksViewState();
}

class _TikToksViewState extends State<TikToksView> {
  PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.startPlaying,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        onPageChanged: widget.setIndex,
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          return FutureBuilder(
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                widget.videoPlayerController =
                    widget.setVideoPlayerController(snapshot.data);
                widget.initVideoPlayerController =
                    widget.videoPlayerController.initialize();
                return FutureBuilder(
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      widget.startPlaying();
                      return Center(
                          child: VideoPlayer(widget.videoPlayerController));
                    } else {
                      return Container();
                    }
                  },
                  future: widget.initVideoPlayerController,
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
            future: fireStorage.getDownloadUrl(path: widget.videos[index]),
          );
        },
      ),
    );
  }
}
