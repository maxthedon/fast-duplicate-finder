enum FileType { file, folder }

class DuplicateGroup {
  final String id;
  final String fileName;
  final List<String> filePaths;
  final int fileSize; // in bytes
  final int duplicateCount;
  final FileType type; // file or folder
  final bool isSelected;

  const DuplicateGroup({
    required this.id,
    required this.fileName,
    required this.filePaths,
    required this.fileSize,
    required this.duplicateCount,
    required this.type,
    this.isSelected = false,
  });

  DuplicateGroup copyWith({
    String? id,
    String? fileName,
    List<String>? filePaths,
    int? fileSize,
    int? duplicateCount,
    FileType? type,
    bool? isSelected,
  }) {
    return DuplicateGroup(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePaths: filePaths ?? this.filePaths,
      fileSize: fileSize ?? this.fileSize,
      duplicateCount: duplicateCount ?? this.duplicateCount,
      type: type ?? this.type,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  String get formattedSize {
    if (fileSize == 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = fileSize.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  int get wastedSpace => fileSize * (duplicateCount - 1);

  String get primaryPath => filePaths.isNotEmpty ? filePaths.first : '';
  
  String get displayName {
    if (type == FileType.folder) {
      return '$fileName ($duplicateCount copies)';
    } else {
      return '$fileName ($duplicateCount copies)';
    }
  }
}
