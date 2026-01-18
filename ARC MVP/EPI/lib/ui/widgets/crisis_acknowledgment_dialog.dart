import 'package:flutter/material.dart';

/// Crisis Acknowledgment Dialog
/// 
/// Shown when user reaches Level 2 intervention (second crisis in 24 hours).
/// Requires user to acknowledge crisis resources before continuing.
class CrisisAcknowledgmentDialog extends StatefulWidget {
  final String message;
  final VoidCallback onAcknowledged;
  
  const CrisisAcknowledgmentDialog({
    Key? key,
    required this.message,
    required this.onAcknowledged,
  }) : super(key: key);
  
  @override
  State<CrisisAcknowledgmentDialog> createState() => 
      _CrisisAcknowledgmentDialogState();
}

class _CrisisAcknowledgmentDialogState 
    extends State<CrisisAcknowledgmentDialog> {
  
  bool _acknowledgedResources = false;
  bool _understands247 = false;
  bool _canReachOut = false;
  
  bool get _allAcknowledged => 
      _acknowledgedResources && _understands247 && _canReachOut;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Crisis Resources',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 20),
            
            // Resource Display
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.blue.shade700, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'National Suicide Prevention Lifeline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 28, top: 4),
                    child: Text(
                      '988 (call or text, 24/7)',
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.message, color: Colors.blue.shade700, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Crisis Text Line',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 28, top: 4),
                    child: Text(
                      'Text HOME to 741741',
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.emergency, color: Colors.red.shade700, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Emergency Services',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 28, top: 4),
                    child: Text(
                      '911',
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            Text(
              'Please confirm before continuing:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            
            // Checkboxes
            CheckboxListTile(
              value: _acknowledgedResources,
              onChanged: (value) => setState(() => _acknowledgedResources = value ?? false),
              title: Text('I have seen the crisis resources'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            CheckboxListTile(
              value: _understands247,
              onChanged: (value) => setState(() => _understands247 = value ?? false),
              title: Text('I understand these are available 24/7'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            CheckboxListTile(
              value: _canReachOut,
              onChanged: (value) => setState(() => _canReachOut = value ?? false),
              title: Text('I can reach out if I need immediate help'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _allAcknowledged 
              ? () {
                  widget.onAcknowledged();
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(
            'I acknowledge these resources',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _allAcknowledged ? Colors.blue : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

/// Helper function to show the crisis acknowledgment dialog
Future<bool> showCrisisAcknowledgmentDialog(
  BuildContext context,
  String message,
) async {
  bool acknowledged = false;
  
  await showDialog(
    context: context,
    barrierDismissible: false, // User must acknowledge
    builder: (BuildContext context) {
      return CrisisAcknowledgmentDialog(
        message: message,
        onAcknowledged: () {
          acknowledged = true;
        },
      );
    },
  );
  
  return acknowledged;
}
