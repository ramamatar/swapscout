import 'package:flutter/material.dart';
import 'trip_preferences.dart';

class DreamTripPage extends StatefulWidget {
  const DreamTripPage({super.key});

  @override
  State<DreamTripPage> createState() => _DreamTripPageState();
}

class _DreamTripPageState extends State<DreamTripPage> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _datesController = TextEditingController();
  final TextEditingController _guestsController = TextEditingController(text: '2');

  @override
  void dispose() {
    _locationController.dispose();
    _datesController.dispose();
    _guestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF8C64),
                              const Color(0xFFFF6B9D),
                              const Color(0xFF4A90E2),
                            ],
                          ),
                        ),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1519817650390-64a93db511aa?w=800',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(); // Empty container if image fails to load
                          },
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.black.withOpacity(0.35),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Describe your\ndream trip',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "We'll find your perfect home swap with AI.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 32),

              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Home Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Using TextField directly instead of CustomInputField for controller access
                      TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'e.g., London, UK',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFF28C64),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Number of Guests',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _guestsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g., 2',
                          prefixIcon: const Icon(Icons.people_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFF28C64),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Available Travel Dates',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _datesController,
                        readOnly: true,
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final DateTimeRange? picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFF28C64),
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black87,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            final String startFormatted = picked.start.toString().split(' ')[0];
                            final String endFormatted = picked.end.toString().split(' ')[0];
                            _datesController.text = "$startFormatted to $endFormatted";
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Select travel dates',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFF28C64),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Simple validation
                    if (_locationController.text.trim().isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter your home location')),
                      );
                      return;
                    }
                    
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripPreferencesPage(
                          homeLocation: _locationController.text.trim(),
                          dates: _datesController.text.trim().isNotEmpty ? _datesController.text.trim() : null,
                          guests: int.tryParse(_guestsController.text.trim()) ?? 2,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF28C64),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

