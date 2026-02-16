import 'package:flutter/material.dart';
import '../widgets/selectable_chip.dart';
import 'matches_results.dart';
import '../services/preference_service.dart';
import '../services/ai_service.dart';

class TripPreferencesPage extends StatefulWidget {
  final String? homeLocation;
  final String? dates;

  const TripPreferencesPage({
    super.key,
    this.homeLocation,
    this.dates,
  });

  @override
  State<TripPreferencesPage> createState() => _TripPreferencesPageState();
}

class _TripPreferencesPageState extends State<TripPreferencesPage> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  bool _isInitialLoading = true;

  final Set<String> selectedMoods = {};

  final Set<String> selectedEnvironments = {};

  final Set<String> selectedLifestyles = {};

  final TextEditingController moodDescriptionController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (mounted) {
       setState(() => _isInitialLoading = false);
    }
  }

  void _toggleMood(String mood) {
    setState(() {
      if (selectedMoods.contains(mood)) {
        selectedMoods.remove(mood);
      } else {
        selectedMoods.add(mood);
      }
    });
  }

  void _toggleEnvironment(String environment) {
    setState(() {
      if (selectedEnvironments.contains(environment)) {
        selectedEnvironments.remove(environment);
      } else {
        selectedEnvironments.add(environment);
      }
    });
  }

  // ignore: unused_element
  void _toggleLifestyle(String lifestyle) {
    setState(() {
      if (selectedLifestyles.contains(lifestyle)) {
        selectedLifestyles.remove(lifestyle);
      } else {
        selectedLifestyles.add(lifestyle);
      }
    });
  }

  @override
  void dispose() {
    moodDescriptionController.dispose();
    super.dispose();
  }



  Future<void> _saveAndGenerateMatches() async {
    setState(() => _isLoading = true);

    try {
      // Combine all selected preferences. Use mood and environment as primary tags
      final allTags = <String>[];
      allTags.addAll(selectedMoods);
      allTags.addAll(selectedEnvironments);
      // selectedLifestyles removed from UI, so not adding here

      // Parse city from mood description (assuming format: "city, country" or just "city")
      String? preferredCity;
      String? preferredCountry;
      final cityText = moodDescriptionController.text.trim();
      if (cityText.isNotEmpty) {
        final parts = cityText.split(',');
        if (parts.length > 1) {
          preferredCity = parts[0].trim();
          preferredCountry = parts[1].trim();
        } else {
          preferredCity = cityText;
        }
      }

      // Save preferences with proper format
      await PreferenceService.setMyPreferences(
        preferredCity: preferredCity,
        preferredCountry: preferredCountry,
        lifestyleTags: allTags.isNotEmpty ? allTags : null,
      );

      // Get AI Suggestion (Top 3)
      final moodDescription = moodDescriptionController.text;
      final aiSuggestions = await AiService.getDestinationSuggestion(
        moodDescription,
        {...selectedMoods, ...selectedEnvironments},
        homeLocation: widget.homeLocation,
        dates: widget.dates,
      );

      if (!mounted) return;

      
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchesResultsPage(
            aiSuggestions: aiSuggestions,
            userDates: widget.dates,
          ),
        ),
      );

      // Clear preferences after returning from results
      if (mounted) {
        setState(() {
          moodDescriptionController.clear();
          selectedMoods.clear();
          selectedEnvironments.clear();
          selectedLifestyles.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Trip Preferences',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C64)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Trip Preferences',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe Your Ideal Trip Mood',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Tell us in your own words what kind of vibe you're seeking.",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: moodDescriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      "e.g., 'A tranquil escape surrounded by nature, perfect for reading and hiking, with cozy evenings by a fireplace.'",
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
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
              const SizedBox(height: 32),

              const Text(
                'Quick Mood Selectors',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Relaxing',
                  'Adventurous',
                  'Romantic',
                  'Social',
                  'Remote work',
                  'History',
                  'Food',
                  'Nightlife',
                  'Nature',
                  'Shopping',
                  'Culture',
                  'Luxury',
                ].map((mood) {
                  return SelectableChip(
                    label: mood,
                    isSelected: selectedMoods.contains(mood),
                    onTap: () => _toggleMood(mood),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              const Text(
                'Preferred Environment',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Beach',
                  'City',
                  'Mountain',
                  'Countryside',
                ].map((environment) {
                  return SelectableChip(
                    label: environment,
                    isSelected: selectedEnvironments.contains(environment),
                    onTap: () => _toggleEnvironment(environment),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              // Generate Matches Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndGenerateMatches,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF28C64),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Generate Matches',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}



