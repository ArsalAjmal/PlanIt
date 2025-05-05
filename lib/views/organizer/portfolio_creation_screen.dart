import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../models/portfolio_model.dart';
import '../../services/portfolio_service.dart';
import '../../widgets/firestore_image.dart';
import '../../constants/app_colors.dart';

class PortfolioCreationScreen extends StatefulWidget {
  final String organizerId;

  const PortfolioCreationScreen({Key? key, required this.organizerId})
    : super(key: key);

  @override
  _PortfolioCreationScreenState createState() =>
      _PortfolioCreationScreenState();
}

class _PortfolioCreationScreenState extends State<PortfolioCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();
  final _portfolioService = PortfolioService();
  final List<String> _selectedEventTypes = [];
  final List<String> _imageUrls = [];
  bool _isLoading = false;

  final List<String> _availableEventTypes = [
    'Wedding',
    'Birthday',
    'Corporate',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      for (var image in images) {
        try {
          // Read the image file
          final File imageFile = File(image.path);
          final Uint8List bytes = await imageFile.readAsBytes();

          // Basic size check - Firestore has 1MB limit
          final int sizeInKB = bytes.length ~/ 1024;

          if (sizeInKB > 500) {
            // Limit to 500KB per image
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Image too large (${sizeInKB}KB). Maximum size is 500KB.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            continue;
          }

          // Convert to base64 for storage in Firestore
          final String base64Image = base64Encode(bytes);

          // Store image in a dedicated collection
          final docRef = await FirebaseFirestore.instance
              .collection('portfolio_images')
              .add({
                'image': base64Image,
                'organizerId': widget.organizerId,
                'createdAt': FieldValue.serverTimestamp(),
              });

          // Use the document ID as the image reference
          final String imageUrl = 'firestore:${docRef.id}';

          setState(() {
            _imageUrls.add(imageUrl);
          });

          print('Image stored in Firestore with ID: ${docRef.id}');
        } catch (e) {
          print('Error storing image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error storing image: ${e.toString().substring(0, math.min(e.toString().length, 100))}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPortfolio() async {
    // First check for required fields
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one image to your portfolio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedEventTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one event type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create a portfolio ID that includes the organizerId for better querying
        final String portfolioId =
            '${widget.organizerId}_${DateTime.now().millisecondsSinceEpoch}';

        print('Creating portfolio with ID: $portfolioId');
        print('OrganizerId: ${widget.organizerId}');
        print('Event types: $_selectedEventTypes');
        print('Images count: ${_imageUrls.length}');

        final portfolio = PortfolioModel(
          id: portfolioId,
          organizerId: widget.organizerId,
          title: _titleController.text,
          description: _descriptionController.text,
          imageUrls: _imageUrls,
          eventTypes: _selectedEventTypes,
          minBudget: double.parse(_minBudgetController.text),
          maxBudget: double.parse(_maxBudgetController.text),
          rating: 0.0,
          totalEvents: 0,
          createdAt: DateTime.now(),
        );

        await _portfolioService.createPortfolio(portfolio);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Portfolio created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        print('Error creating portfolio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating portfolio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFFDE5),
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.creamBackground,
        appBar: null,
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Custom app bar that matches My Portfolios screen
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF9D9DCC),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'Create Portfolio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),

                    // Content scrollable area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Promotional Banner for PlanIt Pro
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6A1B9A),
                                    Color(0xFF9D9DCC),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Left side with text and button
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Upgrade to PlanIt Pro",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            "Get 3x more visibility & client bookings",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton(
                                            onPressed: () {
                                              // Implement subscription process here
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "Pro subscription coming soon!",
                                                  ),
                                                  backgroundColor: Color(
                                                    0xFF6A1B9A,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: const Color(
                                                0xFF6A1B9A,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Upgrade Now",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(
                                                  Icons.arrow_forward,
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Right side with badges
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Icon(
                                        Icons.trending_up,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Portfolio Details Section
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                      top: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(
                                              1.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Portfolio Details",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  TextFormField(
                                    controller: _titleController,
                                    decoration: InputDecoration(
                                      labelText: 'Title',
                                      hintText:
                                          'Enter a descriptive title (e.g., "Arsal Decor")',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.withOpacity(0.1),
                                      labelStyle: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.title,
                                        color: Color(0xFF9D9DCC),
                                        size: 20,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10.0,
                                            horizontal: 12.0,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF9D9DCC),
                                          width: 1,
                                        ),
                                      ),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a title';
                                      }
                                      if (value.length < 3) {
                                        return 'Title must be at least 3 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _descriptionController,
                                    decoration: InputDecoration(
                                      labelText: 'Description',
                                      hintText:
                                          'Describe your services and expertise',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.withOpacity(0.1),
                                      alignLabelWithHint: true,
                                      labelStyle: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 10.0,
                                            horizontal: 12.0,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF9D9DCC),
                                          width: 1,
                                        ),
                                      ),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                    maxLines: 3,
                                    textAlignVertical: TextAlignVertical.top,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a description';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Budget Section
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                      top: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(
                                              1.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Budget Range",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _minBudgetController,
                                          decoration: InputDecoration(
                                            labelText: 'Min Budget',
                                            hintText: 'Minimum amount',
                                            hintStyle: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.withOpacity(
                                              0.1,
                                            ),
                                            labelStyle: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.currency_rupee,
                                              color: Color(0xFF9D9DCC),
                                              size: 20,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 10.0,
                                                  horizontal: 12.0,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF9D9DCC),
                                                width: 1,
                                              ),
                                            ),
                                            isDense: true,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter min budget';
                                            }
                                            if (double.tryParse(value) ==
                                                null) {
                                              return 'Please enter a valid number';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _maxBudgetController,
                                          decoration: InputDecoration(
                                            labelText: 'Max Budget',
                                            hintText: 'Maximum amount',
                                            hintStyle: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.withOpacity(
                                              0.1,
                                            ),
                                            labelStyle: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.currency_rupee,
                                              color: Color(0xFF9D9DCC),
                                              size: 20,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 10.0,
                                                  horizontal: 12.0,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF9D9DCC),
                                                width: 1,
                                              ),
                                            ),
                                            isDense: true,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter max budget';
                                            }
                                            if (double.tryParse(value) ==
                                                null) {
                                              return 'Please enter a valid number';
                                            }
                                            final minBudget =
                                                double.tryParse(
                                                  _minBudgetController.text,
                                                ) ??
                                                0;
                                            final maxBudget =
                                                double.tryParse(value) ?? 0;
                                            if (maxBudget < minBudget) {
                                              return 'Max budget must be >= min budget';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Event Types Section
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                      top: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(
                                              1.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Event Types",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Wrap(
                                    spacing: 8,
                                    children:
                                        _availableEventTypes.map((type) {
                                          return FilterChip(
                                            label: Text(type),
                                            selected: _selectedEventTypes
                                                .contains(type),
                                            selectedColor: AppColors
                                                .primaryPurple
                                                .withOpacity(0.7),
                                            backgroundColor: Colors.white,
                                            checkmarkColor: Colors.white,
                                            side: BorderSide(
                                              color: AppColors.primaryPurple,
                                            ),
                                            onSelected: (selected) {
                                              setState(() {
                                                if (selected) {
                                                  _selectedEventTypes.add(type);
                                                } else {
                                                  _selectedEventTypes.remove(
                                                    type,
                                                  );
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                  ),
                                  const SizedBox(height: 16),

                                  // Images Section
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                      top: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(
                                              1.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "Portfolio Image",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  _imageUrls.isEmpty
                                      ? ElevatedButton.icon(
                                        onPressed: _pickImages,
                                        icon: const Icon(
                                          Icons.add_photo_alternate,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Add Image',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryPurple,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      )
                                      : Column(
                                        children: [
                                          Container(
                                            height: 200,
                                            child: GridView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 3,
                                                    crossAxisSpacing: 8,
                                                    mainAxisSpacing: 8,
                                                  ),
                                              itemCount: _imageUrls.length,
                                              itemBuilder: (context, index) {
                                                return Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: FirestoreImage(
                                                        imageUrl:
                                                            _imageUrls[index],
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 0,
                                                      top: 0,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                    0.5,
                                                                  ),
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                            ),
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.delete,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
                                                          onPressed: () {
                                                            setState(() {
                                                              _imageUrls
                                                                  .removeAt(
                                                                    index,
                                                                  );
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            onPressed: _pickImages,
                                            icon: const Icon(
                                              Icons.add_photo_alternate,
                                              color: Colors.white,
                                            ),
                                            label: const Text(
                                              'Add More Image',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryPurple,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _submitPortfolio,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primaryPurple,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Create Portfolio',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

// Widget to load and display Firestore images
class FirestoreImage extends StatelessWidget {
  final String imageUrl;

  const FirestoreImage({Key? key, required this.imageUrl}) : super(key: key);

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
            return Image.memory(bytes, fit: BoxFit.cover);
          } catch (e) {
            return Center(child: Icon(Icons.error, color: Colors.red));
          }
        },
      );
    } else {
      // Handle other URL types if needed
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
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
