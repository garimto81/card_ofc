import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _TutorialPage(
      title: 'Welcome to OFC Pineapple',
      icon: Icons.style,
      content: 'Open Face Chinese Poker is a card game where you arrange '
          '13 cards into three poker hands:\n\n'
          '• Bottom (5 cards) - Strongest hand\n'
          '• Middle (5 cards) - Medium hand\n'
          '• Top (3 cards) - Weakest hand\n\n'
          'Your Bottom must beat your Middle, and your Middle must beat your Top!',
    ),
    _TutorialPage(
      title: 'Pineapple Dealing',
      icon: Icons.casino,
      content: 'Round 1: You receive 5 cards and place them all.\n\n'
          'Rounds 2-5: You receive 3 cards each round:\n'
          '• Place 2 cards on your board\n'
          '• Discard 1 card\n\n'
          'After 5 rounds, your board is complete with 13 cards.',
    ),
    _TutorialPage(
      title: 'Scoring',
      icon: Icons.scoreboard,
      content: 'After all rounds, boards are compared line by line:\n\n'
          '• Win a line = +1 point\n'
          '• Win all 3 lines (Scoop) = +3 bonus\n'
          '• Royalties = bonus points for strong hands\n\n'
          'Foul: If your hands are not in order (Bottom ≥ Middle ≥ Top), '
          'you lose 6 points!',
    ),
    _TutorialPage(
      title: 'Fantasyland',
      icon: Icons.auto_awesome,
      content: 'Place a pair of Queens or better in your Top line to enter '
          'Fantasyland!\n\n'
          'In Fantasyland, you receive all 14 cards at once and arrange '
          'them however you want.\n\n'
          'This is a huge advantage — aim for it!',
    ),
    _TutorialPage(
      title: 'Ready to Play!',
      icon: Icons.play_arrow,
      content: 'Tips for beginners:\n\n'
          '• Start by filling your Bottom with strong cards\n'
          '• Keep your Top weak to avoid Foul\n'
          '• Watch for Royalty opportunities\n'
          '• Aim for Fantasyland with QQ+ on Top\n\n'
          'Good luck!',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[900],
      appBar: AppBar(
        title: const Text('How to Play'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(page.icon, size: 64, color: Colors.teal[300]),
                      const SizedBox(height: 24),
                      Text(
                        page.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        page.content,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.teal[100],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (index) {
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.teal[300]
                      : Colors.teal[700],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentPage > 0
                      ? () => _controller.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  child: Text(
                    'Back',
                    style: TextStyle(color: Colors.teal[300]),
                  ),
                ),
                if (_currentPage < _pages.length - 1)
                  ElevatedButton(
                    onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Got it!'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPage {
  final String title;
  final IconData icon;
  final String content;

  const _TutorialPage({
    required this.title,
    required this.icon,
    required this.content,
  });
}
