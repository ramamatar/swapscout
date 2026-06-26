import 'package:flutter/material.dart';

class CompatibilityScoreWidget extends StatelessWidget {
  final int score;
  final String explanation;
  final Map<String, dynamic> factors;

  const CompatibilityScoreWidget({
    super.key,
    required this.score,
    required this.explanation,
    required this.factors,
  });

  Widget _buildChecklistRow(IconData icon, Color iconColor, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors based on score
    final Color mainColor = score >= 80 
        ? Colors.green 
        : score >= 60 
            ? Colors.orange 
            : Colors.red;

    final Color bgColor = score >= 80 
        ? Colors.green.shade50 
        : score >= 60 
            ? Colors.orange.shade50 
            : Colors.red.shade50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: mainColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Compatibility Score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: mainColor.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$score%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Checklist
          if (factors['date_match'] != null && factors['date_match']['matched'] == true)
            _buildChecklistRow(Icons.check_circle, Colors.green, 'Dates align with availability'),
            
          if (factors['guest_capacity'] != null)
            factors['guest_capacity']['score'] == 100
                ? _buildChecklistRow(Icons.check_circle, Colors.green, 'Accommodates all ${factors['guest_capacity']['requested_guest_count']} requested ${factors['guest_capacity']['requested_guest_count'] == 1 ? 'guest' : 'guests'}')
                : _buildChecklistRow(Icons.cancel, Colors.red, 'Cannot accommodate ${factors['guest_capacity']['requested_guest_count']} requested ${factors['guest_capacity']['requested_guest_count'] == 1 ? 'guest' : 'guests'} (capacity: ${factors['guest_capacity']['listing_capacity']})'),

          if (factors['amenities'] != null) ...[
            if (factors['amenities']['matched_amenities'] != null && (factors['amenities']['matched_amenities'] as List).isNotEmpty)
              _buildChecklistRow(Icons.check_circle, Colors.green, 'Available: ${(factors['amenities']['matched_amenities'] as List).join(', ')}'),
            if (factors['amenities']['missing_amenities'] != null && (factors['amenities']['missing_amenities'] as List).isNotEmpty)
              _buildChecklistRow(Icons.cancel, Colors.red, 'Missing: ${(factors['amenities']['missing_amenities'] as List).join(', ')}'),
          ],

          if (factors['bio_lifestyle'] != null) ...[
            if (factors['bio_lifestyle']['matched_traits'] != null && (factors['bio_lifestyle']['matched_traits'] as List).isNotEmpty)
              _buildChecklistRow(Icons.check_circle, Colors.green, 'Lifestyle match: ${(factors['bio_lifestyle']['matched_traits'] as List).join(', ')}'),
            if (factors['bio_lifestyle']['conflicting_traits'] != null && (factors['bio_lifestyle']['conflicting_traits'] as List).isNotEmpty)
              _buildChecklistRow(Icons.warning, Colors.orange, 'Lifestyle missing: ${(factors['bio_lifestyle']['conflicting_traits'] as List).join(', ')}'),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          
          // AI Explanation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: mainColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  explanation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
