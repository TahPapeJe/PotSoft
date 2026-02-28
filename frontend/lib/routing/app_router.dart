import 'package:go_router/go_router.dart';
import '../features/citizen/screens/citizen_screen.dart';
import '../features/contractor/screens/contractor_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const CitizenScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const ContractorScreen(),
    ),
  ],
);
