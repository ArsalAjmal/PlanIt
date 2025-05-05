import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/portfolio_service.dart';
import '../models/response_model.dart';
import './login_view.dart';
import '../constants/app_colors.dart';

class PendingOrdersScreen extends StatefulWidget {
  final String orderId;

  const PendingOrdersScreen({super.key, required this.orderId});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen>
    with SingleTickerProviderStateMixin {
  final PortfolioService _portfolioService = PortfolioService();
  bool _isLoading = true;
  ResponseModel? _order;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadOrderData();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('responses')
              .doc(widget.orderId)
              .get();

      if (doc.exists) {
        setState(() {
          _order = ResponseModel.fromMap(doc.data()!);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Order not found: ${widget.orderId}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading order: $e');
    }
  }

  Future<void> _markAsCompleted() async {
    if (_order == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _portfolioService.markResponseAsCompleted(_order!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as complete!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Pop back to the previous screen with a success result
      Navigator.of(context).pop('ORDER_COMPLETED');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error marking order as complete: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error marking order as complete'),
          backgroundColor: AppColors.error,
        ),
      );
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

    if (_isLoading) {
      return SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryPurple,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading order details...',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Background pattern
            Positioned.fill(child: _buildPatternBackground()),

            SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
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
                          'Order Details',
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
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Order not found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The order with ID ${widget.orderId.substring(0, 8)} could not be found',
                            style: const TextStyle(color: Colors.black45),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(child: _buildPatternBackground()),

          SafeArea(
            child: Column(
              children: [
                // App bar with hero animation
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Hero(
                          tag: 'order_${_order!.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              'Order Details - ${_order!.id.substring(0, 8)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadOrderData,
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEventSummaryCard(),
                          const SizedBox(height: 16),
                          if (_order!.clientResponse.isNotEmpty) ...[
                            _buildMessageCard(
                              'Client Message',
                              _order!.clientResponse,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 16),

                          // Animated button
                          TweenAnimationBuilder(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween<double>(begin: 1.0, end: 1.05),
                            builder: (context, scale, child) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => setState(() {}),
                                onExit: (_) => setState(() {}),
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _markAsCompleted,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: const Text(
                                      'Mark as Complete',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSummaryCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryPurple, AppColors.darkPurple],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _order!.eventName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _order!.eventType,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.date_range,
                'Date',
                _order!.eventDate.toString().substring(0, 10),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.account_circle, 'Client', _order!.clientName),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.account_balance_wallet,
                'Budget',
                'PKR ${_order!.budget.toStringAsFixed(0)}',
              ),

              // Add additional information section
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Additional Information',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Display colors as swatches instead of text
              _buildColorsRow(),
              const SizedBox(height: 12),

              _buildInfoRow(
                Icons.camera_alt,
                'Photographer',
                _order!.needsPhotographer ? 'Required' : 'Not Required',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.notes,
                'Notes',
                _order!.additionalNotes.isEmpty
                    ? 'None'
                    : _order!.additionalNotes,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New method to display color swatches
  Widget _buildColorsRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryPurple, AppColors.darkPurple],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.25),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(Icons.color_lens, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Colors',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Primary: ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(int.parse(_order!.primaryColor)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Secondary: ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(int.parse(_order!.secondaryColor)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryPurple, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageCard(String title, String message) {
    return Card(
      elevation: 4,
      shadowColor: AppColors.primaryPurple.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.message,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatternBackground() {
    return CustomPaint(painter: PatternPainter());
  }
}

// Pattern Painter copied from organizer_home_screen.dart for consistency
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primaryPurple.withOpacity(0.02)
          ..style = PaintingStyle.fill;

    // Draw subtle pattern with triangles and dots
    final patternSize = 30.0;
    final rows = (size.height / patternSize).ceil();
    final cols = (size.width / patternSize).ceil();

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        // Only draw some patterns for a sparse effect
        if ((i + j) % 5 == 0) {
          final x = j * patternSize;
          final y = i * patternSize;

          // Draw small dot
          canvas.drawCircle(
            Offset(x + patternSize / 2, y + patternSize / 2),
            1.5,
            paint,
          );
        }

        // Draw triangles in very limited positions
        if ((i + j) % 9 == 0) {
          final x = j * patternSize;
          final y = i * patternSize;

          final path = Path();
          path.moveTo(x + patternSize / 2, y);
          path.lineTo(x + patternSize, y + patternSize);
          path.lineTo(x, y + patternSize);
          path.close();

          canvas.drawPath(
            path,
            paint..color = AppColors.primaryPurple.withOpacity(0.01),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
