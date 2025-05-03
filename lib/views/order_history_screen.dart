import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/order_history_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/response_model.dart';
import '../constants/app_colors.dart';
import 'feedback_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderHistoryController _controller = OrderHistoryController();
  bool _isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    // Get current user ID from Firebase Auth
    final user = _auth.currentUser;

    if (user != null) {
      // Initialize the stream first
      _controller.initOrdersStream(user.uid);
      // Then fetch orders to populate the initial list
      await _controller.fetchOrders(user.uid);
    } else {
      print('Cannot fetch orders: User is not logged in');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar - Updated to match client_home_screen style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Order History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadOrders,
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF9D9DCC),
              tabs: const [Tab(text: 'Ongoing'), Tab(text: 'Completed')],
            ),

            // Divider
            Container(
              height: 1,
              color: const Color(0xFF9D9DCC).withOpacity(0.3),
            ),

            // Order List with Tabs
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<List<ResponseModel>>(
                        stream: _controller.ordersStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              _controller.orders.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          // Use stream data if available, otherwise use the controller's cached data
                          final allOrders = snapshot.data ?? _controller.orders;

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              // Ongoing Orders Tab
                              _buildOrdersList(
                                allOrders
                                    .where(
                                      (order) => order.status != 'completed',
                                    )
                                    .toList(),
                              ),

                              // Completed Orders Tab
                              _buildOrdersList(
                                allOrders
                                    .where(
                                      (order) => order.status == 'completed',
                                    )
                                    .toList(),
                              ),
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<ResponseModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No orders found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Status chip positioned at top right
              Positioned(
                top: 8,
                right: 8,
                child: _buildStatusChip(order.status),
              ),
              // Main content row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Image placeholder with padding - will be replaced with Firebase image later
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  // Order details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event name (without status chip)
                          Text(
                            order.eventName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Event Type:', order.eventType),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            'Event Date:',
                            DateFormat('MMM dd, yyyy').format(order.eventDate),
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            'Amount:',
                            'PKR ${NumberFormat('#,###').format(order.budget)}',
                          ),
                          const SizedBox(height: 8),
                          // Chat icon button - only show for non-completed orders
                          if (order.status.toLowerCase() != 'completed')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // This will be implemented with Firebase chat later
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Chat will be implemented soon',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9D9DCC),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.chat,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          // Review button - only show for completed orders
                          if (order.status.toLowerCase() == 'completed')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => const FeedbackScreen(
                                                isInBottomNavBar: false,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          'Tap to ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          'rate',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.thumb_up,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                      ],
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    String displayStatus = status.isEmpty ? 'pending' : status;
    displayStatus = displayStatus.toLowerCase();

    // Set display text based on status
    switch (displayStatus) {
      case 'accepted':
        displayStatus = 'Ongoing';
        break;
      case 'pending':
        displayStatus = 'Ongoing';
        break;
      case 'completed':
        displayStatus = 'Completed';
        break;
      case 'rejected':
        displayStatus = 'Rejected';
        break;
    }

    // Use light green for all status chips
    Color chipColor;

    if (displayStatus == 'Ongoing') {
      chipColor = Colors.orange.shade300;
    } else if (displayStatus == 'Completed') {
      chipColor = const Color(0xFFAED581); // Light green for completed status
    } else if (displayStatus == 'Rejected') {
      chipColor = Colors.red;
    } else {
      chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: chipColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
