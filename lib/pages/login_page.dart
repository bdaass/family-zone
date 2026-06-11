import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:google_sign_in/google_sign_in.dart';

// Safe dynamic imports for native-only packages to prevent web runtime crashes
import 'package:flutter_image_compress/flutter_image_compress.dart' as compress_lib show FlutterImageCompress; 
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- STATE VARIABLES ---
  String userRole = 'guest'; // Automatically changes to client, employee, or admin

  String selectedSeason = 'All Seasons';
  String selectedSex = 'Female';

  final List<String> seasons = ['All Seasons', 'Summer', 'Winter', 'Sport'];
  final List<String> sexes = ['Female', 'Male', 'Children'];
  final List<String> types = ['clothes', 'shoes', 'lingery', 'sacs', 'scarf'];

  // --- CONTROLLERS & MEDIA VARIABLES ---
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  File? _selectedImageFile; // Tracks local selected file for mobile
  XFile? _webImageFile;     // Tracks local selected file bytes for Web platforms
  bool _isUploading = false; // Prevents double submissions & shows loading spinner

  String _formSeason = 'summer';
  String _formSex = 'female';
  String _formType = 'clothes';

  // Theme Constants for a Premium E-commerce Look
  final Color brandBlack = const Color(0xFF111111);
  final Color brandWhite = const Color(0xFFFFFFFF);
  final Color backgroundChalk = const Color(0xFFF6F6F6);
  final Color textMuted = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _listenToAuthState(); 
  }

  // ==========================================
  // CODE LOGIC: BACKEND & AUTHENTICATION
  // ==========================================
  void _listenToAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user == null) {
        if (mounted) {
          setState(() {
            userRole = 'guest';
          });
        }
      } else {
        await _createUserProfileIfNew(user);
        await _fetchUserRole(user.uid);
      }
    });
  }

  Future<void> _createUserProfileIfNew(User user) async {
    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDocRef.get();

      if (!docSnapshot.exists) {
        await userDocRef.set({
          'uid': user.uid,
          'name': user.displayName ?? user.email?.split('@')[0] ?? 'New Client',
          'email': user.email,
          'role': 'client', 
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error creating user profile: $e");
    }
  }

  Future<void> _fetchUserRole(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        if (mounted) {
          setState(() {
            userRole = userDoc.data()!['role'] ?? 'client';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user role: $e");
    }
  }

  Future<void> registerWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      _showToast('Account registered successfully!');
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      _showToast('Welcome back!');
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      User? user = userCredential.user;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'role': 'client',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      _showToast('Logged in successfully!');
    } catch (e) {
      _showErrorDialog("Authentication Error: ${e.toString()}");
    }
  }

  Future<void> logOutUser() async {
    await FirebaseAuth.instance.signOut();
    _showToast('Logged out.');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (kIsWeb) {
          _webImageFile = pickedFile;
        } else {
          _selectedImageFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<File?> _compressImage(File file) async {
    if (kIsWeb) return file; 

    try {
      final tempDir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(tempDir.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");
      final result = await compress_lib.FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
      );
      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint("Compression skipped on this target platform environment: $e");
      return file;
    }
  }

  Future<void> _submitProduct() async {
    if (userRole != 'admin' && userRole != 'employee') {
      _showToast("Unauthorized operation.");
      return;
    }
    final desc = _descController.text.trim();
    final priceText = _priceController.text.trim();

    if (desc.isEmpty || priceText.isEmpty) {
      _showToast('Please enter both description and price.');
      return;
    }
    final price = double.tryParse(priceText);
    if (price == null) {
      _showToast('Please enter a valid numeric price.');
      return;
    }
    if ((kIsWeb && _webImageFile == null) || (!kIsWeb && _selectedImageFile == null)) {
      _showToast('Please pick an item image first.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      String imageUrl = '';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('product_images/$fileName');

      if (kIsWeb) {
        final bytes = await _webImageFile!.readAsBytes();
        final uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      } else {
        File? fileToUpload = _selectedImageFile;
        File? compressed = await _compressImage(_selectedImageFile!);
        if (compressed != null) fileToUpload = compressed;
        final uploadTask = storageRef.putFile(fileToUpload!);
        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('products').add({
        'description': desc,
        'price': price,
        'imageUrl': imageUrl,
        'season': _formSeason,
        'sex': _formSex,
        'type': _formType,
        'visibility': true,
        'sold': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      _descController.clear();
      _priceController.clear();
      setState(() {
        _selectedImageFile = null;
        _webImageFile = null;
      });
      _showToast('Product uploaded successfully!');
    } catch (e) {
      _showToast('Error uploading product: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: brandBlack, behavior: SnackBarBehavior.floating),
    );
  }

  void _showErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Authentication Error', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(errorMsg, style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: brandBlack)))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool useInlineSidebar = kIsWeb && screenWidth > 900;

    return Scaffold(
      backgroundColor: backgroundChalk,
      appBar: AppBar(
        title: Text(
          'FAMILY ZONE',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3.0, color: brandBlack, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: brandWhite,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1),
        ),
        iconTheme: IconThemeData(color: brandBlack),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: userRole == 'guest'
                ? IconButton(
                    icon: const Icon(Icons.person_outline_rounded),
                    onPressed: _showAuthModal,
                    tooltip: 'Login / Register',
                  )
                : TextButton.icon(
                    onPressed: logOutUser,
                    icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                    label: Text(
                      userRole.toUpperCase(),
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
          )
        ],
      ),
      drawer: useInlineSidebar ? null : _buildSidebarDrawer(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (useInlineSidebar)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: brandWhite,
                border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: _buildFilterSidebarContent(),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth > 600 ? 32.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userRole == 'admin' || userRole == 'employee') ...[
                    _buildStaffDashboardPanel(),
                    const SizedBox(height: 32),
                  ],
                  _buildCatalogHeaderSection(),
                  const SizedBox(height: 24),
                  _buildProductGridDisplay(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSidebarContent() {
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      children: [
        Text('COLLECTIONS', style: TextStyle(fontWeight: FontWeight.w800, color: brandBlack, fontSize: 13, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ...seasons.map((s) {
          final bool isSelected = selectedSeason == s;
          return InkWell(
            onTap: () => setState(() => selectedSeason = s),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected ? brandBlack : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.toUpperCase(),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? brandWhite : textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
        Text('CATEGORIES', style: TextStyle(fontWeight: FontWeight.w800, color: brandBlack, fontSize: 13, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ...sexes.map((g) {
          final bool isSelected = selectedSex == g;
          return InkWell(
            onTap: () => setState(() => selectedSex = g),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected ? brandBlack : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                g.toUpperCase(),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? brandWhite : textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStaffDashboardPanel() {
    return Container(
      decoration: BoxDecoration(
        color: brandWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: brandBlack,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Text(
                  'STORE MANAGEMENT PANEL — ${userRole.toUpperCase()}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: brandWhite, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          TextField(
                            controller: _descController,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'Item Label / Title',
                              labelStyle: TextStyle(color: textMuted),
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              hintText: "e.g., Oversized Linen Summer Shirt",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: brandBlack, width: 1.5), borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _priceController,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'Retail Price (\$)',
                              labelStyle: TextStyle(color: textMuted),
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              hintText: "0.00",
                              prefixIcon: const Icon(Icons.attach_money_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: brandBlack, width: 1.5), borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final bool dynamicHasImage = (kIsWeb && _webImageFile != null) || (!kIsWeb && _selectedImageFile != null);
                          return InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 138,
                              decoration: BoxDecoration(
                                color: backgroundChalk,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
                              ),
                              child: dynamicHasImage
                                  ? Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: kIsWeb
                                                ? Image.network(_webImageFile!.path, fit: BoxFit.cover)
                                                : Image.file(_selectedImageFile!, fit: BoxFit.cover),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(9),
                                            color: Colors.black.withOpacity(0.2),
                                          ),
                                        ),
                                        const Center(
                                          child: Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => setState(() {
                                              _webImageFile = null;
                                              _selectedImageFile = null;
                                            }),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        )
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_outlined, color: textMuted, size: 24),
                                        const SizedBox(height: 8),
                                        Text('Upload Apparel Cover', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brandBlack)),
                                        const SizedBox(height: 2),
                                        Text('JPEG or PNG format', style: TextStyle(fontSize: 10, color: textMuted)),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _formSeason,
                        decoration: InputDecoration(labelText: 'Season Flag', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                        items: ['summer', 'winter', 'sport', 'all seasons']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (val) => setState(() => _formSeason = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _formSex,
                        decoration: InputDecoration(labelText: 'Segment Profile', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                        items: ['male', 'female', 'children']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (val) => setState(() => _formSex = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _formType,
                        decoration: InputDecoration(labelText: 'Classification', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                        items: types
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (val) => setState(() => _formType = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandBlack,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isUploading
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: brandWhite, strokeWidth: 2))
                        : Text('PUBLISH ITEM ARCHIVE', style: TextStyle(color: brandWhite, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedSeason == 'All Seasons' ? 'ESSENTIAL CATALOG' : '${selectedSeason.toUpperCase()} LINE',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: brandBlack, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: brandBlack, borderRadius: BorderRadius.circular(4)),
                  child: Text(selectedSex.toUpperCase(), style: TextStyle(color: brandWhite, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('Displaying ready-to-wear drops', style: TextStyle(fontSize: 13, color: textMuted)),
              ],
            ),
          ],
        ),
        if (!kIsWeb || MediaQuery.of(context).size.width <= 900)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: brandWhite, shape: BoxShape.circle, border: Border.all(color: Colors.grey.withOpacity(0.2))),
              child: const Icon(Icons.tune_rounded, size: 20),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
      ],
    );
  }

  Widget _buildProductGridDisplay() {
    final double width = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    if (width < 600) crossAxisCount = 1;
    else if (width < 950) crossAxisCount = 2;
    else if (width < 1300) crossAxisCount = 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6, 
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 28,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        List<String> mockTitles = [
          "Minimalist Autumn Overcoat",
          "Classic Comfort Urban Sneakers",
          "Structured Silk Runway Wrap",
          "Monochrome Leather Utility Tote",
          "Premium Knitted Head Scarf",
          "Tailored Cropped Casual Blazer"
        ];
        List<double> mockPrices = [189.00, 95.50, 120.00, 240.00, 45.00, 160.00];
        
        return ProductCardItem(
          description: mockTitles[index % mockTitles.length],
          price: mockPrices[index % mockPrices.length],
          imageUrl: "", 
          isSoldOut: index == 3, 
        );
      },
    );
  }

  Widget _buildSidebarDrawer() {
    return Drawer(
      backgroundColor: brandWhite,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: brandBlack),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('FAMILY ZONE', style: TextStyle(color: brandWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? 'Guest Shopping Mode',
                    style: TextStyle(color: brandWhite.withOpacity(0.6), fontSize: 11),
                  )
                ],
              ),
            ),
          ),
          Expanded(child: _buildFilterSidebarContent()),
          const Divider(),
          if (userRole != 'guest')
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Sign Out Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                logOutUser();
              },
            )
          else
            ListTile(
              leading: Icon(Icons.login_rounded, color: brandBlack),
              title: const Text('Access/Create Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                _showAuthModal();
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAuthModal() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: brandWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isSignUp ? 'REGISTER ACCOUNT' : 'STORE LOG IN',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: brandBlack, letterSpacing: 1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: brandBlack), borderRadius: BorderRadius.circular(10)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password Space',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: brandBlack), borderRadius: BorderRadius.circular(10)),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();
                        if (email.isEmpty || password.isEmpty) {
                          _showToast('Please fill all fields');
                          return;
                        }
                        Navigator.pop(context);
                        if (isSignUp) {
                          await registerWithEmail(email, password);
                        } else {
                          await loginWithEmail(email, password);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: brandBlack, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN', style: TextStyle(color: brandWhite, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await loginWithGoogle();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.redAccent),
                      label: Text('Continue with Google', style: TextStyle(color: brandBlack, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => setModalState(() => isSignUp = !isSignUp),
                    child: Text(
                      isSignUp ? 'Already a member? Sign in instead' : 'New to Family Zone? Register here',
                      style: TextStyle(color: brandBlack, decoration: TextDecoration.underline, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- REUSABLE DESIGN APPAREL CARD ---
class ProductCardItem extends StatelessWidget {
  final String description;
  final double price;
  final String imageUrl;
  final bool isSoldOut;

  const ProductCardItem({
    super.key,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isSoldOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
              image: imageUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: isSoldOut
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.favorite_border_rounded, color: Colors.black45, size: 20),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111111), letterSpacing: -0.2),
              ),
              const SizedBox(height: 3),
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}