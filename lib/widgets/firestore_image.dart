import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';

// A simple cache to store decoded images
class _ImageCache {
  static final Map<String, Uint8List> _cache = {};

  static Uint8List? getImage(String key) {
    return _cache[key];
  }

  static void cacheImage(String key, Uint8List data) {
    _cache[key] = data;
  }

  static bool hasImage(String key) {
    return _cache.containsKey(key);
  }
}

class FirestoreImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const FirestoreImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<FirestoreImage> createState() => _FirestoreImageState();
}

class _FirestoreImageState extends State<FirestoreImage> {
  Uint8List? _imageData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(FirestoreImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _errorMessage = 'No image URL provided';
      });
      return;
    }

    // Check if it's a Firestore reference
    if (widget.imageUrl.startsWith('firestore:')) {
      final String docId = widget.imageUrl.substring(10);

      // Check if image is already in memory cache
      if (_ImageCache.hasImage(docId)) {
        setState(() {
          _imageData = _ImageCache.getImage(docId);
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('portfolio_images')
                .doc(docId)
                .get();

        if (!doc.exists) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Image not found';
          });
          return;
        }

        final data = doc.data() as Map<String, dynamic>;
        final String? base64Image = data['image'] as String?;

        if (base64Image == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Invalid image data';
          });
          return;
        }

        try {
          final bytes = base64Decode(base64Image);
          // Store in cache
          _ImageCache.cacheImage(docId, bytes);

          if (mounted) {
            setState(() {
              _imageData = bytes;
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Failed to decode image';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error loading image: $e';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // For Firestore images
    if (widget.imageUrl.startsWith('firestore:')) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_errorMessage != null) {
        return Center(child: Icon(Icons.error, color: Colors.red));
      }

      if (_imageData != null) {
        return Image.memory(
          _imageData!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        );
      }

      return const Center(child: CircularProgressIndicator());
    } else {
      // Handle regular URLs with caching
      return Image.network(
        widget.imageUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: 400, // Add caching for images
        cacheHeight: 300,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
        },
      );
    }
  }
}
