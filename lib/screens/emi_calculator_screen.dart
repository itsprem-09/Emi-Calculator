import 'package:emi_calculator/components/amount.dart';
import 'package:emi_calculator/components/compare.dart';
import 'package:emi_calculator/components/emi.dart';
import 'package:emi_calculator/components/roi.dart';
import 'package:emi_calculator/components/tensure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../models/emi_model.dart';
import '../utils/formatter.dart';

// Import for math min function
// import 'dart:math' as math;

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen>
    with SingleTickerProviderStateMixin {

  // Tab controller
  late TabController _tabController;
  late PageController _pageController;

  int index = 0;

  List screens = [Emi(), Amount(), Tensure(), Roi(), Compare()];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _pageController = PageController();
    
    // Sync PageView with TabBar
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final padding = isSmallScreen ? 16.0 : 24.0;
    final buttonHeight = isSmallScreen ? 40.0 : 48.0;
    final buttonWidth = isSmallScreen ? 100.0 : 120.0;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('EMI Calculator'),
          centerTitle: true,
          backgroundColor: const Color(0xFF3498db),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 4,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                isScrollable: true,
                onTap: (value) {
                  setState(() {
                    index = value;
                  });
                },
                labelPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12.0 : 16.0),
                tabs: const [
                  Tab(child: Text('EMI')),
                  Tab(child: Text('AMOUNT')),
                  Tab(child: Text('TENURE')),
                  Tab(child: Text('ROI')),
                  Tab(child: Text('COMPARE')),
                ],
              ),
            ),
          ),
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: (value) {
            setState(() {
              index = value;
              _tabController.animateTo(value);
            });
          },
          children: [
            screens[0], // EMI
            screens[1], // AMOUNT
            screens[2], // TENURE
            screens[3], // ROI
            screens[4], // COMPARE
          ],
        ),
      ),
    );
  }
}

