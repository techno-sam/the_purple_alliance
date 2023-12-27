import 'package:flutter/material.dart';
import 'package:the_purple_alliance/utils/util.dart';

class StarRating extends StatefulWidget {
  const StarRating({
    super.key,
    required this.initialRating,
    required this.averageRating,
    this.onChanged,
    this.starCount = 5,
    this.starSize = 20.0,
    this.interactable = true,
    this.color,
  });

  final double initialRating;
  final double? averageRating;
  final Function(double)? onChanged;
  final int starCount;
  final double starSize;
  final bool interactable;
  final Color? color;

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  double _rating = 0.0;

  _StarRatingState();


  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  Widget buildStar(BuildContext context, int index) {
    Icon icon;
    if (index >= _rating) {
      icon = const Icon(Icons.star_border);
    } else if (index > _rating - 1 && index < _rating) {
      icon = Icon(
        Icons.star_half,
        color: widget.color,
      );
    } else {
      icon = Icon(
        Icons.star,
        color: widget.color,
      );
    }
    return InkResponse(
      onTap: widget.interactable ? () {
        if (widget.onChanged != null) {
          widget.onChanged!(index + 1.0);
        }
        setState(() {
          _rating = index + 1.0;
        });
      } : null,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widget.starCount; i++)
          buildStar(context, i),
        if (widget.averageRating != null)
          const SizedBox(width: 4),
        if (widget.averageRating != null)
          Text("Avg: ${roundDouble(widget.averageRating ?? 0, 2)}/${widget.starCount+0.0}"),
      ],
    );
  }
}