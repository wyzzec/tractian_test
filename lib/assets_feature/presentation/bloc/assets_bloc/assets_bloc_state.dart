part of 'assets_bloc.dart';

sealed class AssetsState {}

final class AssetsInitial extends AssetsState {}

final class AssetsLoading extends AssetsState {}

final class AssetsLoaded extends AssetsState {
  final RootEntity assets;

  AssetsLoaded({required this.assets});
}

final class AssetsError extends AssetsState {
  final String message;

  AssetsError({required this.message});
}
