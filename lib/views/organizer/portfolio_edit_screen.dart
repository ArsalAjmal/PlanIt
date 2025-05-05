import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../../models/portfolio_model.dart';
import '../../services/portfolio_service.dart';
import '../../widgets/firestore_image.dart';
import '../../constants/app_colors.dart';

class PortfolioEditScreen extends StatefulWidget {
  final PortfolioModel portfolio;

  const PortfolioEditScreen({Key? key, required this.portfolio})
    : super(key: key);

  @override
  _PortfolioEditScreenState createState() => _PortfolioEditScreenState();
}

class _PortfolioEditScreenState extends State<PortfolioEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();
  final _portfolioService = PortfolioService();
  final List<String> _selectedEventTypes = [];
  final List<String> _imageUrls = [];
  bool _isLoading = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> _availableEventTypes = [
    'Wedding',
    'Birthday',
    'Corporate',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.portfolio.title;
    _descriptionController.text = widget.portfolio.description;
    _minBudgetController.text = widget.portfolio.minBudget.toString();
    _maxBudgetController.text = widget.portfolio.maxBudget.toString();
    _selectedEventTypes.addAll(widget.portfolio.eventTypes);
    _imageUrls.addAll(widget.portfolio.imageUrls);
  }

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
                'organizerId': widget.portfolio.organizerId,
                'createdAt': FieldValue.serverTimestamp(),
              });

          // Use the document ID as the image reference
          final String imageUrl = 'firestore:${docRef.id}';

          setState(() {
            _imageUrls.add(imageUrl);
          });
        } catch (e) {
          print('Error storing image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error uploading image')),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteImage(int index) async {
    final url = _imageUrls[index];

    try {
      if (url.startsWith('firestore:')) {
        // Delete from Firestore
        final String docId = url.substring(10); // Remove 'firestore:' prefix
        await FirebaseFirestore.instance
            .collection('portfolio_images')
            .doc(docId)
            .delete();
      } else {
        // Legacy Firebase Storage URL
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      }

      setState(() {
        _imageUrls.removeAt(index);
      });
    } catch (e) {
      print('Error deleting image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error deleting image')));
    }
  }

  Future<void> _updatePortfolio() async {
    if (_formKey.currentState!.validate() &&
        _imageUrls.isNotEmpty &&
        _selectedEventTypes.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      final updatedPortfolio = PortfolioModel(
        id: widget.portfolio.id,
        organizerId: widget.portfolio.organizerId,
        title: _titleController.text,
        description: _descriptionController.text,
        imageUrls: _imageUrls,
        eventTypes: _selectedEventTypes,
        minBudget: double.parse(_minBudgetController.text),
        maxBudget: double.parse(_maxBudgetController.text),
        rating: widget.portfolio.rating,
        totalEvents: widget.portfolio.totalEvents,
        createdAt: widget.portfolio.createdAt,
      );

      try {
        await _portfolioService.updatePortfolio(updatedPortfolio);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portfolio updated successfully')),
        );
      } catch (e) {
        print('Error updating portfolio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating portfolio')),
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  hintText: 'Enter a descriptive title',
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
                                  contentPadding: const EdgeInsets.symmetric(
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
                                  contentPadding: const EdgeInsets.symmetric(
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
                                        fillColor: Colors.grey.withOpacity(0.1),
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter min budget';
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
                                        fillColor: Colors.grey.withOpacity(0.1),
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter max budget';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
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
                                        selected: _selectedEventTypes.contains(
                                          type,
                                        ),
                                        selectedColor: AppColors.primaryPurple
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
                                              _selectedEventTypes.remove(type);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 16),
                              // Portfolio Images section
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
                                      "Portfolio Images",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  if (_imageUrls.isEmpty) {
                                    return ElevatedButton.icon(
                                      onPressed: _pickImages,
                                      icon: const Icon(
                                        Icons.add_photo_alternate,
                                      ),
                                      label: const Text('Add Images'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primaryPurple,
                                      ),
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        GridView.builder(
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
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: FirestoreImage(
                                                    imageUrl: _imageUrls[index],
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: InkWell(
                                                    onTap:
                                                        () =>
                                                            _deleteImage(index),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: ElevatedButton.icon(
                                            onPressed: _pickImages,
                                            icon: const Icon(
                                              Icons.add_photo_alternate,
                                              color: Colors.white,
                                            ),
                                            label: const Text(
                                              'Change Image',
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
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _updatePortfolio,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryPurple,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Update Portfolio',
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
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF9D9DCC),
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Edit Portfolio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
