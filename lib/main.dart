import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/home.dart';
import 'package:form_app/area_selector_screen.dart';
import 'package:form_app/invoiceMasterManagement.dart';
import 'package:form_app/invoice_series_management.dart';
import 'package:form_app/login_screen.dart';
import 'package:form_app/pipeline_dashboard.dart';
import 'package:form_app/dispatch_dashboard.dart';
import 'package:form_app/step1.dart';
import 'package:form_app/step2.dart';
import 'package:form_app/step3.dart';
import 'package:form_app/step4.dart';
import 'package:form_app/step5.dart';
import 'package:form_app/garage_slip_pending.dart';
import 'package:form_app/CompanyManagement/companyhome.dart';
import 'package:form_app/PartyManagement/partyhome.dart';
import 'package:form_app/RouteManagement/routehome.dart';
import 'package:form_app/TransportManagement/transportmanagement.dart';
import 'package:form_app/admin_users_screen.dart';
import 'package:form_app/telecalling_screen.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register AuthService as a permanent singleton before runApp
  Get.put(AuthService(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'C&F Activity Manager',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      unknownRoute: GetPage(name: '/notfound', page: () => const LoginScreen()),
      getPages: [
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/select', page: () => const AreaSelectorScreen()),
        GetPage(name: '/', page: () => const HomePage()),
        GetPage(
            name: '/InvoiceMasterManagement',
            page: () => const InvoiceMasterManagement()),
        GetPage(
            name: '/InvoiceSeriesManagement',
            page: () => const InvoiceSeriesManagement()),
        GetPage(
            name: '/PipelineDashboard', page: () => const PipelineDashboard()),
        GetPage(
            name: '/DispatchDashboard', page: () => const DispatchDashboard()),
        GetPage(name: '/Step1', page: () => Step1()),
        GetPage(name: '/Step2', page: () => Step2()),
        GetPage(name: '/Step3', page: () => Step3()),
        GetPage(name: '/Step4', page: () => Step4()),
        GetPage(name: '/Step5', page: () => Step5()),
        GetPage(
            name: '/GarageSlipPending',
            page: () => const GarageSlipPendingPage()),
        GetPage(name: '/CompanyHome', page: () => const CompanyHome()),
        GetPage(name: '/PartyHome', page: () => const PartyHome()),
        GetPage(name: '/RouteHome', page: () => const RouteHome()),
        GetPage(
            name: '/Transportmanagement',
            page: () => const Transportmanagement()),
        GetPage(
            name: AdminUsersScreen.routeName,
            page: () => const AdminUsersScreen()),
        GetPage(
            name: TelecallingScreen.routeName,
            page: () => const TelecallingScreen()),
      ],
    );
  }
}
