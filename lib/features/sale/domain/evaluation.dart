/// A review/evaluation appointment scraped from the intra dashboard
/// (#collapseEvaluations on profile.intra.42.fr/).
class Evaluation {
  final String text;
  final String? url;
  final DateTime? when;

  const Evaluation({
    required this.text,
    this.url,
    this.when,
  });
}
