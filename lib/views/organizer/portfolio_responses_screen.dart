import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/response_model.dart';
import '../../services/portfolio_service.dart';

class PortfolioResponsesScreen extends StatefulWidget {
  final String organizerId;

  const PortfolioResponsesScreen({Key? key, required this.organizerId})
    : super(key: key);

  @override
  _PortfolioResponsesScreenState createState() =>
      _PortfolioResponsesScreenState();
}

class _PortfolioResponsesScreenState extends State<PortfolioResponsesScreen> {
  final _portfolioService = PortfolioService();
  String _selectedStatus = 'All';
  final Map<String, Timer> _eventTimers = {};

  @override
  void dispose() {
    _eventTimers.values.forEach((timer) => timer.cancel());
    super.dispose();
  }

  void _startEventTimer(ResponseModel response) {
    if (_eventTimers.containsKey(response.id)) {
      _eventTimers[response.id]?.cancel();
    }

    final now = DateTime.now();
    final eventDate = response.eventDate;
    final duration = eventDate.difference(now);

    if (duration.isNegative) {
      return;
    }

    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        final remaining = eventDate.difference(DateTime.now());
        if (remaining.isNegative) {
          timer.cancel();
          _eventTimers.remove(response.id);
        }
      });
    });

    _eventTimers[response.id] = timer;
  }

  String _getTimeRemaining(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.isNegative) {
      return 'Event has passed';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return '$days days, $hours hours, $minutes minutes, $seconds seconds';
  }

  Future<void> _updateResponseStatus(
    ResponseModel response,
    String status,
  ) async {
    try {
      await _portfolioService.updateResponseStatus(response.id, status);
      if (status == 'accepted') {
        _startEventTimer(response);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Response $status successfully')));
    } catch (e) {
      print('Error updating response status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating response status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio Responses'),
        backgroundColor: const Color(0xFF9D9DCC),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
              ),
              items:
                  ['All', 'Pending', 'Accepted', 'Rejected'].map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ResponseModel>>(
              stream: _portfolioService.getResponsesForOrganizer(
                widget.organizerId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final responses = snapshot.data ?? [];
                final filteredResponses =
                    _selectedStatus == 'All'
                        ? responses
                        : responses
                            .where(
                              (r) =>
                                  r.status.toLowerCase() ==
                                  _selectedStatus.toLowerCase(),
                            )
                            .toList();

                if (filteredResponses.isEmpty) {
                  return const Center(child: Text('No responses found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredResponses.length,
                  itemBuilder: (context, index) {
                    final response = filteredResponses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  response.eventName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(response.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    response.status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Client: ${response.clientName}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Event Type: ${response.eventType}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Event Date: ${DateFormat('MMM dd, yyyy').format(response.eventDate)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (response.status == 'accepted') ...[
                              const SizedBox(height: 8),
                              Text(
                                'Time Remaining: ${_getTimeRemaining(response.eventDate)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Budget: PKR ${response.budget}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(response.primaryColor),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(response.secondaryColor),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Photographer: ${response.needsPhotographer ? 'Required' : 'Not Required'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (response.additionalNotes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Notes: ${response.additionalNotes}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                            if (response.status == 'pending') ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed:
                                        () => _updateResponseStatus(
                                          response,
                                          'rejected',
                                        ),
                                    child: const Text(
                                      'Reject',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed:
                                        () => _updateResponseStatus(
                                          response,
                                          'accepted',
                                        ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF9D9DCC),
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
