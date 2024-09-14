part of 'company_bloc.dart';

abstract class CompanyState {
}

class CompanyInitial extends CompanyState {}

class CompanyLoading extends CompanyState {}

class CompanyLoaded extends CompanyState {
  final List<CompanyEntity> companies;

  CompanyLoaded({required this.companies});

}

class CompanyError extends CompanyState {
  final String message;

  CompanyError({required this.message});

}
