import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/sms_service.dart';
import 'widgets/otp_verification_dialog.dart';

class AddContactPage extends StatefulWidget {
  final String userId; // pass logged-in user's ID
  const AddContactPage({super.key, required this.userId});

  @override
  State<AddContactPage > createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final SMSService _smsService = SMSService();
  bool _isLoading = false;

  Future<void> _saveContact() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Check if user already has 5 contacts (SRS requirement)
        QuerySnapshot existingContacts = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('contacts')
            .get();

        if (existingContacts.docs.length >= 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ Maximum 5 emergency contacts allowed"),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Check if contact already exists
        QuerySnapshot duplicateCheck = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('contacts')
            .where('phone', isEqualTo: _phoneController.text.trim())
            .get();

        if (duplicateCheck.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ Contact already exists"),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Request SMS permission
        bool hasPermission = await _smsService.requestSMSPermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ SMS permission required for verification"),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Save contact to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('contacts')
            .add({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'verified': false,
          'addedAt': FieldValue.serverTimestamp(),
        });

        // Generate verification OTP and send SMS
        String verificationOTP = _smsService.generateOTP();
        print('🔢 DEBUG: Generated verification OTP for ${_phoneController.text.trim()}: $verificationOTP'); // Debug print
        
        bool smsSent = await _smsService.sendVerificationSMS(
          _phoneController.text.trim(),
          _nameController.text.trim(),
          verificationOTP,
        );

        if (!smsSent) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ Failed to send verification SMS"),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Store the verification OTP in Firestore for later verification
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('contacts')
            .where('phone', isEqualTo: _phoneController.text.trim())
            .get()
            .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            snapshot.docs.first.reference.update({
              'verificationOTP': verificationOTP,
              'otpSentAt': FieldValue.serverTimestamp(),
            });
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Contact saved! Verification SMS sent."),
              backgroundColor: Colors.green,
            ),
          );
        }

        _nameController.clear();
        _phoneController.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Error: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
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
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        backgroundColor: Colors.pink[300],
      ),
      body: Column(
        children: [
          // Add Contact Form
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[50],
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Add Emergency Contact",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Contact Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? "Enter a name" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: "10-digit number",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Enter phone number";
                      if (value.length != 10) return "Phone must be 10 digits";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveContact,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[300],
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Add Contact & Send Verification"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Contacts List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('contacts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading contacts'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = snapshot.data?.docs ?? [];

                if (contacts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.contacts, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No emergency contacts added yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add up to 5 emergency contacts',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index].data() as Map<String, dynamic>;
                    final contactId = contacts[index].id;
                    final isVerified = contact['verified'] ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isVerified ? Colors.green : Colors.orange,
                          child: Icon(
                            isVerified ? Icons.verified : Icons.pending,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(contact['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact['phone'] ?? 'No phone'),
                            Text(
                              isVerified ? 'Verified ✓' : 'Pending verification',
                              style: TextStyle(
                                color: isVerified ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Delete button
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteContact(contactId),
                            ),
                            // Verify button (only if not verified)
                            if (!isVerified)
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => OTPVerificationDialog(
                                      contactId: contactId,
                                      userId: widget.userId,
                                      contactName: contact['name'] ?? 'Contact',
                                      phoneNumber: contact['phone'] ?? '',
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),

                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Footer info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Text(
              '📱 Emergency contacts will receive SMS alerts with your location when you press the SOS button. Maximum 5 contacts allowed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContact(String contactId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('contacts')
          .doc(contactId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Contact deleted"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting contact: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
