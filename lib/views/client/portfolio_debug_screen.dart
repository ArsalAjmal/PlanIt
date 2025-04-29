import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/portfolio_model.dart';

class PortfolioDebugScreen extends StatefulWidget {
  @override
  _PortfolioDebugScreenState createState() => _PortfolioDebugScreenState();
}

class _PortfolioDebugScreenState extends State<PortfolioDebugScreen> {
  final _titleController = TextEditingController();
  final List<PortfolioModel> _portfolios = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _debugInfo = '';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPortfolios() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _portfolios.clear();
      _debugInfo = 'Loading portfolios...';
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('portfolios').get();

      setState(() {
        _debugInfo =
            'Found ${snapshot.docs.length} documents in portfolios collection';
      });

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _debugInfo += '\nNo documents found in portfolios collection!';
        });
        return;
      }

      for (var doc in snapshot.docs) {
        try {
          print('Document ID: ${doc.id}');
          print('Document data: ${doc.data()}');

          final portfolio = PortfolioModel.fromMap(doc.data());
          _portfolios.add(portfolio);

          setState(() {
            _debugInfo += '\nSuccessfully loaded portfolio: ${portfolio.title}';
          });
        } catch (e) {
          print('Error parsing portfolio ${doc.id}: $e');
          setState(() {
            _debugInfo += '\nError parsing portfolio ${doc.id}: $e';
          });
        }
      }

      setState(() {
        _isLoading = false;
        _debugInfo +=
            '\nFinished loading portfolios. Found ${_portfolios.length} valid portfolios.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading portfolios: $e';
        _debugInfo += '\nError: $e';
      });
    }
  }

  Future<void> _checkFirestoreCollections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _debugInfo = 'Checking Firestore collections...';
    });

    try {
      // Attempt to get collections
      final db = FirebaseFirestore.instance;

      // Check portfolios collection
      final portfoliosSnapshot = await db.collection('portfolios').get();

      setState(() {
        _debugInfo +=
            '\n\nPortfolios collection: ${portfoliosSnapshot.docs.length} documents';
      });

      if (portfoliosSnapshot.docs.isNotEmpty) {
        setState(() {
          _debugInfo +=
              '\nSample document ID: ${portfoliosSnapshot.docs.first.id}';
          _debugInfo +=
              '\nSample data keys: ${portfoliosSnapshot.docs.first.data().keys.join(', ')}';
        });
      }

      // Check organizers collection
      final organizersSnapshot = await db.collection('organizers').get();

      setState(() {
        _debugInfo +=
            '\n\nOrganizers collection: ${organizersSnapshot.docs.length} documents';
      });

      // Check responses collection
      final responsesSnapshot = await db.collection('responses').get();

      setState(() {
        _debugInfo +=
            '\n\nResponses collection: ${responsesSnapshot.docs.length} documents';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error checking collections: $e';
        _debugInfo += '\nError: $e';
      });
    }
  }

  void _searchPortfolios() {
    if (_titleController.text.isEmpty) return;

    final searchTerm = _titleController.text.toLowerCase();
    setState(() {
      _portfolios.sort((a, b) {
        final aContains = a.title.toLowerCase().contains(searchTerm);
        final bContains = b.title.toLowerCase().contains(searchTerm);

        if (aContains && !bContains) return -1;
        if (!aContains && bContains) return 1;
        return 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio Debug'),
        backgroundColor: const Color(0xFF9D9DCC),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Portfolio Title',
                    hintText: 'Enter title to search',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _searchPortfolios(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loadAllPortfolios,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D9DCC),
                        ),
                        child: const Text('Load All Portfolios'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _checkFirestoreCollections,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9D9DCC),
                        ),
                        child: const Text('Check Collections'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _titleController.text = "Arsal decor";
                          });
                          _searchPortfolios();
                          _loadAllPortfolios();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Search "Arsal decor"'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Direct check for a specific title
                          setState(() {
                            _isLoading = true;
                            _errorMessage = '';
                            _debugInfo =
                                'Directly searching for "Arsal decor"...';
                          });

                          try {
                            final snapshot =
                                await FirebaseFirestore.instance
                                    .collection('portfolios')
                                    .where('title', isEqualTo: 'Arsal decor')
                                    .get();

                            if (snapshot.docs.isEmpty) {
                              setState(() {
                                _debugInfo +=
                                    '\nNo exact match found for "Arsal decor"';
                              });

                              // Try a case-insensitive search
                              setState(() {
                                _debugInfo +=
                                    '\n\nTrying case-insensitive search...';
                              });

                              final allPortfoliosSnapshot =
                                  await FirebaseFirestore.instance
                                      .collection('portfolios')
                                      .get();

                              final matchingPortfolios =
                                  allPortfoliosSnapshot.docs
                                      .where(
                                        (doc) =>
                                            (doc.data()['title'] as String?)
                                                ?.toLowerCase()
                                                .contains(
                                                  'arsal decor'.toLowerCase(),
                                                ) ??
                                            false,
                                      )
                                      .toList();

                              if (matchingPortfolios.isEmpty) {
                                setState(() {
                                  _debugInfo +=
                                      '\nNo case-insensitive matches found either.';
                                  _debugInfo += '\n\nPossible issues:';
                                  _debugInfo +=
                                      '\n1. The portfolio was not created successfully';
                                  _debugInfo +=
                                      '\n2. It was created with a different title';
                                  _debugInfo +=
                                      '\n3. There might be a typo in your search';
                                });
                              } else {
                                setState(() {
                                  _debugInfo +=
                                      '\nFound ${matchingPortfolios.length} similar titles:';
                                  for (var doc in matchingPortfolios) {
                                    _debugInfo +=
                                        '\n- "${doc.data()['title']}"';
                                  }
                                });
                              }
                            } else {
                              setState(() {
                                _debugInfo +=
                                    '\nFound an exact match for "Arsal decor"!';
                                _debugInfo +=
                                    '\nDocument ID: ${snapshot.docs.first.id}';
                              });
                            }

                            setState(() {
                              _isLoading = false;
                            });
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                              _debugInfo += '\nError during search: $e';
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Check for "Arsal decor"'),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                if (_debugInfo.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_debugInfo),
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _portfolios.isEmpty
                    ? Center(
                      child: Text(
                        'No portfolios found\n${_debugInfo.isEmpty ? 'Click "Load All Portfolios" to check database' : ''}',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : ListView.builder(
                      itemCount: _portfolios.length,
                      itemBuilder: (context, index) {
                        final portfolio = _portfolios[index];
                        final bool isMatch =
                            _titleController.text.isNotEmpty &&
                            portfolio.title.toLowerCase().contains(
                              _titleController.text.toLowerCase(),
                            );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: isMatch ? Colors.green[50] : null,
                          child: ListTile(
                            title: Text(
                              portfolio.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMatch ? Colors.green[800] : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${portfolio.id}'),
                                Text('Organizer: ${portfolio.organizerId}'),
                                Text(
                                  'Event Types: ${portfolio.eventTypes.join(", ")}',
                                ),
                                Text(
                                  'Budget: PKR ${portfolio.minBudget} - PKR ${portfolio.maxBudget}',
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
