import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/ideas_provider.dart';
import 'add_idea_screen.dart';

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      context.read<IdeasProvider>().initialize();
    });
  }

  Future<void> _deleteIdea({
    required BuildContext context,
    required String id,
  }) async {
    try {
      await context.read<IdeasProvider>().deleteIdea(id);
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Idea deleted.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _refreshIdeas(BuildContext context) async {
    try {
      await context.read<IdeasProvider>().fetchIdeas();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IdeasProvider>();
    final ideas = provider.ideas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ideas Board'),
        actions: [
          IconButton(
            onPressed: provider.isLoading ? null : () => _refreshIdeas(context),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: provider.isLoading && ideas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refreshIdeas(context),
              child: ideas.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 140),
                        Center(
                          child: Text(
                            'No ideas available yet. Pull down to refresh.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: ideas.length,
                      itemBuilder: (context, index) {
                        final idea = ideas[index];

                        return Dismissible(
                          key: ValueKey(idea.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: Theme.of(context).colorScheme.error,
                            child: Icon(
                              Icons.delete,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            await _deleteIdea(context: context, id: idea.id);
                            return false;
                          },
                          child: Card(
                            child: ListTile(
                              title: Text(idea.title),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(idea.description),
                                    const SizedBox(height: 4),
                                    Text(
                                      'By: ${idea.userId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _deleteIdea(context: context, id: idea.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddIdeaScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Idea'),
      ),
    );
  }
}
