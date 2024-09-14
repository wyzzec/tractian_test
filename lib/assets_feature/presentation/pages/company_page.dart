import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tractian_test/assets_feature/presentation/bloc/company_bloc/company_bloc_factory.dart';
import 'package:tractian_test/assets_feature/presentation/pages/assets_page.dart';
import '../../domain/entities/company_entity.dart';
import '../bloc/company_bloc/company_bloc.dart';
import '../widgets/shimmer_loading.dart';

class CompanyPage extends StatelessWidget {
  const CompanyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Image(
          image: AssetImage('assets/logo_tractian.png'),
          width: 126,
        ),
        centerTitle: true,
        backgroundColor: Colors.black87,
      ),
      body: BlocProvider(
        create: (context) => CompanyBlocFactory().create()..fetchCompanies(),
        child: BlocBuilder<CompanyBloc, CompanyState>(
          builder: (context, state) {
            if (state is CompanyLoading) {
              return _LoadingList();
            }
            if (state is CompanyLoaded) {
              return _CompanyList(companies: state.companies);
            }
            if (state is CompanyError) {
              return Center(child: Text(state.message));
            }

            return Container();
          },
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: ShimmerLoading(
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompanyList extends StatelessWidget {
  final List<CompanyEntity> companies;

  const _CompanyList({required this.companies});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: companies.length,
      itemBuilder: (context, index) {
        final company = companies[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          child: Material(
            color: const Color.fromRGBO(33, 136, 255, 1),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssetsPage(
                      companyId: company.id,
                    ),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 26),
                child: Row(
                  children: [
                    const Image(
                      image: AssetImage('assets/unit.png'),
                      height: 25,
                      width: 25,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      company.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
