import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';

class FirestoreImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Check if it's a Firestore reference
    if (imageUrl.startsWith('firestore:')) {
      final String docId = imageUrl.substring(10); // Remove 'firestore:' prefix

      return FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('portfolio_images')
                .doc(docId)
                .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Icon(Icons.error, color: Colors.red));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Icon(Icons.broken_image, color: Colors.grey));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String? base64Image = data['image'] as String?;

          if (base64Image == null) {
            return Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey),
            );
          }

          try {
            final Uint8List bytes = base64Decode(base64Image);
            return Image.memory(bytes, fit: fit, width: width, height: height);
          } catch (e) {
            return Center(child: Icon(Icons.error, color: Colors.red));
          }
        },
      );
    } else {
      // Handle regular URLs
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
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
