class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  int get totalPages => pageSize <= 0 ? 0 : (total / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
  bool get isEmpty => items.isEmpty;

  PaginatedResult<R> map<R>(R Function(T item) transform) {
    return PaginatedResult<R>(
      items: items.map(transform).toList(growable: false),
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  PaginatedResult<T> copyWith({
    List<T>? items,
    int? page,
    int? pageSize,
    int? total,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
    );
  }
}
