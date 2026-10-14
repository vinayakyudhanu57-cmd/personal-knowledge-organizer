# ==============================================================================
# Personal Knowledge Organizer - Core Logic & Data Processing
# R/functions.R
# ==============================================================================

# Standard schema definition
KNOWLEDGE_COLUMNS <- c(
  "id", "title", "content", "item_type", "topic",
  "tags", "importance", "source_url", "created_at", "updated_at"
)

ALLOWED_TYPES <- c("Note", "Concept", "Article", "Website", "Tutorial", "Book")
ALLOWED_IMPORTANCE <- c("Low", "Medium", "High")

# ------------------------------------------------------------------------------
# 1. Tag Parsing & Normalization
# ------------------------------------------------------------------------------

#' Normalize a single tag string (lowercase, trimmed)
normalize_tag <- function(tag) {
  if (is.null(tag) || is.na(tag)) return("")
  t <- tolower(trimws(as.character(tag)))
  # Replace consecutive whitespace or special chars with hyphen
  t <- gsub("[^a-z0-9+#_\\.-]+", "-", t)
  t <- gsub("^-+|-+$", "", t)
  return(t)
}

#' Parse a comma/semicolon-separated string or character vector into unique tags
parse_tags <- function(tags_input) {
  if (is.null(tags_input) || length(tags_input) == 0) return(character(0))
  if (is.list(tags_input)) tags_input <- unlist(tags_input)
  
  if (length(tags_input) == 1 && is.character(tags_input)) {
    raw_pieces <- unlist(strsplit(tags_input, "[,;]+"))
  } else {
    raw_pieces <- unlist(lapply(tags_input, function(x) unlist(strsplit(as.character(x), "[,;]+"))))
  }
  
  cleaned <- vapply(raw_pieces, normalize_tag, FUN.VALUE = character(1), USE.NAMES = FALSE)
  cleaned <- cleaned[nzchar(cleaned)]
  return(unique(cleaned))
}

#' Format a character vector of tags back into a clean comma-separated string
format_tags <- function(tag_vec) {
  cleaned <- parse_tags(tag_vec)
  if (length(cleaned) == 0) return("")
  paste(cleaned, collapse = ", ")
}

# ------------------------------------------------------------------------------
# 2. File Handling & CSV Persistence
# ------------------------------------------------------------------------------

#' Ensure an empty or initialized CSV file exists
init_knowledge_file <- function(file_path) {
  dir_name <- dirname(file_path)
  if (!dir.exists(dir_name)) {
    dir.create(dir_name, recursive = TRUE, showWarnings = FALSE)
  }
  if (!file.exists(file_path) || file.info(file_path)$size == 0) {
    empty_df <- data.frame(matrix(ncol = length(KNOWLEDGE_COLUMNS), nrow = 0))
    colnames(empty_df) <- KNOWLEDGE_COLUMNS
    write.csv(empty_df, file = file_path, row.names = FALSE, quote = TRUE, fileEncoding = "UTF-8")
  }
}

#' Load all knowledge items from CSV safely
load_knowledge_items <- function(file_path) {
  init_knowledge_file(file_path)
  
  tryCatch({
    df <- read.csv(
      file_path,
      stringsAsFactors = FALSE,
      colClasses = "character",
      strip.white = FALSE,
      fill = TRUE,
      encoding = "UTF-8"
    )
    
    # Ensure all required columns exist
    for (col in KNOWLEDGE_COLUMNS) {
      if (!col %in% colnames(df)) {
        df[[col]] <- character(nrow(df))
      }
    }
    
    # Reorder columns and sanitize NA values
    df <- df[, KNOWLEDGE_COLUMNS, drop = FALSE]
    for (col in KNOWLEDGE_COLUMNS) {
      df[[col]][is.na(df[[col]])] <- ""
      df[[col]] <- as.character(df[[col]])
    }
    
    return(df)
  }, error = function(e) {
    warning("Error reading knowledge CSV: ", e$message, ". Returning empty collection.")
    empty_df <- data.frame(matrix(ncol = length(KNOWLEDGE_COLUMNS), nrow = 0))
    colnames(empty_df) <- KNOWLEDGE_COLUMNS
    return(empty_df)
  })
}

#' Save knowledge items data.frame to CSV with proper quoting
save_knowledge_items <- function(items_df, file_path) {
  dir_name <- dirname(file_path)
  if (!dir.exists(dir_name)) {
    dir.create(dir_name, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Ensure columns exist and order is respected
  for (col in KNOWLEDGE_COLUMNS) {
    if (!col %in% colnames(items_df)) {
      items_df[[col]] <- ""
    }
    items_df[[col]][is.na(items_df[[col]])] <- ""
    items_df[[col]] <- as.character(items_df[[col]])
  }
  items_df <- items_df[, KNOWLEDGE_COLUMNS, drop = FALSE]
  
  write.csv(
    items_df,
    file = file_path,
    row.names = FALSE,
    quote = TRUE,
    fileEncoding = "UTF-8"
  )
  return(TRUE)
}

# ------------------------------------------------------------------------------
# 3. Validation
# ------------------------------------------------------------------------------

#' Validate a knowledge item record
validate_knowledge_item <- function(item, existing_df = NULL, is_edit = FALSE) {
  errors <- character(0)
  
  # Normalize fields
  title <- trimws(as.character(if (!is.null(item$title)) item$title else ""))
  content <- trimws(as.character(if (!is.null(item$content)) item$content else ""))
  item_type <- trimws(as.character(if (!is.null(item$item_type)) item$item_type else ""))
  topic <- trimws(as.character(if (!is.null(item$topic)) item$topic else ""))
  importance <- trimws(as.character(if (!is.null(item$importance)) item$importance else "Medium"))
  source_url <- trimws(as.character(if (!is.null(item$source_url)) item$source_url else ""))
  id <- trimws(as.character(if (!is.null(item$id)) item$id else ""))
  
  # Required title
  if (!nzchar(title)) {
    errors <- c(errors, "Title is required and cannot be blank.")
  } else if (nchar(title) > 200) {
    errors <- c(errors, "Title must be 200 characters or fewer.")
  }
  
  # Required content
  if (!nzchar(content)) {
    errors <- c(errors, "Note content or concept explanation is required.")
  }
  
  # Valid item_type
  if (!nzchar(item_type)) {
    errors <- c(errors, "Item type is required.")
  } else if (!item_type %in% ALLOWED_TYPES) {
    errors <- c(errors, paste0("Item type must be one of: ", paste(ALLOWED_TYPES, collapse = ", ")))
  }
  
  # Required topic
  if (!nzchar(topic)) {
    errors <- c(errors, "Topic/Category is required.")
  }
  
  # Valid importance
  if (!importance %in% ALLOWED_IMPORTANCE) {
    errors <- c(errors, paste0("Importance must be one of: ", paste(ALLOWED_IMPORTANCE, collapse = ", ")))
  }
  
  # Optional URL validation
  if (nzchar(source_url)) {
    url_pattern <- "^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$"
    if (!grepl(url_pattern, source_url, perl = TRUE)) {
      errors <- c(errors, "Source URL must start with http:// or https:// and have a valid web address format.")
    }
  }
  
  # Unique ID validation for new items
  if (!is_edit && !is.null(existing_df) && nrow(existing_df) > 0 && nzchar(id)) {
    if (id %in% existing_df$id) {
      errors <- c(errors, paste0("An item with ID '", id, "' already exists."))
    }
  }
  
  list(
    valid = (length(errors) == 0),
    errors = errors
  )
}

# ------------------------------------------------------------------------------
# 4. CRUD Operations
# ------------------------------------------------------------------------------

#' Add a new knowledge item to CSV
add_knowledge_item <- function(new_item, file_path) {
  df <- load_knowledge_items(file_path)
  
  val <- validate_knowledge_item(new_item, existing_df = df, is_edit = FALSE)
  if (!val$valid) {
    return(list(success = FALSE, errors = val$errors, item = NULL))
  }
  
  # Generate unique ID if not supplied
  item_id <- trimws(as.character(if (!is.null(new_item$id) && nzchar(new_item$id)) new_item$id else ""))
  if (!nzchar(item_id)) {
    timestamp_part <- format(Sys.time(), "%Y%m%d%H%M%S")
    rand_hex <- paste(sample(c(0:9, letters[1:6]), 4, replace = TRUE), collapse = "")
    item_id <- paste0("item_", timestamp_part, "_", rand_hex)
  }
  
  today_str <- as.character(Sys.Date())
  created_at <- if (!is.null(new_item$created_at) && nzchar(new_item$created_at)) as.character(new_item$created_at) else today_str
  updated_at <- today_str
  
  cleaned_tags <- format_tags(new_item$tags)
  
  new_row <- data.frame(
    id = item_id,
    title = trimws(as.character(new_item$title)),
    content = trimws(as.character(new_item$content)),
    item_type = trimws(as.character(new_item$item_type)),
    topic = trimws(as.character(new_item$topic)),
    tags = cleaned_tags,
    importance = trimws(as.character(if (!is.null(new_item$importance)) new_item$importance else "Medium")),
    source_url = trimws(as.character(if (!is.null(new_item$source_url)) new_item$source_url else "")),
    created_at = created_at,
    updated_at = updated_at,
    stringsAsFactors = FALSE
  )
  
  updated_df <- rbind(df, new_row)
  save_knowledge_items(updated_df, file_path)
  
  return(list(
    success = TRUE,
    errors = character(0),
    item = as.list(new_row[1, ])
  ))
}

#' Update an existing knowledge item
update_knowledge_item <- function(item_id, updated_fields, file_path) {
  df <- load_knowledge_items(file_path)
  
  if (nrow(df) == 0 || !item_id %in% df$id) {
    return(list(success = FALSE, errors = c(paste0("Item with ID '", item_id, "' not found.")), item = NULL))
  }
  
  idx <- which(df$id == item_id)
  existing_item <- as.list(df[idx, ])
  
  # Merge updated fields
  merged <- existing_item
  for (nm in names(updated_fields)) {
    if (nm %in% KNOWLEDGE_COLUMNS && nm != "id" && nm != "created_at") {
      merged[[nm]] <- updated_fields[[nm]]
    }
  }
  
  val <- validate_knowledge_item(merged, existing_df = df, is_edit = TRUE)
  if (!val$valid) {
    return(list(success = FALSE, errors = val$errors, item = NULL))
  }
  
  df$title[idx] <- trimws(as.character(merged$title))
  df$content[idx] <- trimws(as.character(merged$content))
  df$item_type[idx] <- trimws(as.character(merged$item_type))
  df$topic[idx] <- trimws(as.character(merged$topic))
  df$tags[idx] <- format_tags(merged$tags)
  df$importance[idx] <- trimws(as.character(merged$importance))
  df$source_url[idx] <- trimws(as.character(if (!is.null(merged$source_url)) merged$source_url else ""))
  df$updated_at[idx] <- as.character(Sys.Date())
  
  save_knowledge_items(df, file_path)
  
  return(list(
    success = TRUE,
    errors = character(0),
    item = as.list(df[idx, ])
  ))
}

#' Delete an item by ID
delete_knowledge_item <- function(item_id, file_path) {
  df <- load_knowledge_items(file_path)
  
  if (nrow(df) == 0 || !item_id %in% df$id) {
    return(list(success = FALSE, errors = c(paste0("Item with ID '", item_id, "' not found."))))
  }
  
  updated_df <- df[df$id != item_id, , drop = FALSE]
  save_knowledge_items(updated_df, file_path)
  
  return(list(success = TRUE, deleted_id = item_id))
}

# ------------------------------------------------------------------------------
# 5. Search and Multi-Criteria Filtering
# ------------------------------------------------------------------------------

#' Search titles & content (case-insensitive keyword matching) and filter by multiple criteria
search_and_filter_items <- function(
  items_df,
  query = "",
  topic = "",
  item_type = "",
  tag = "",
  importance = "",
  sort_by = "updated_at",
  sort_dir = "desc"
) {
  if (is.null(items_df) || nrow(items_df) == 0) {
    return(data.frame(matrix(ncol = length(KNOWLEDGE_COLUMNS), nrow = 0, dimnames = list(NULL, KNOWLEDGE_COLUMNS))))
  }
  
  matches <- rep(TRUE, nrow(items_df))
  
  # 1. Search Query: case-insensitive keyword matching across title and content
  query_str <- trimws(as.character(query))
  if (nzchar(query_str)) {
    # Escape special regex characters so user can search plain symbols like C++, R#, etc.
    escaped_query <- gsub("([.\\^$*+?()[{\\\\|])", "\\\\\\1", query_str)
    title_match <- grepl(escaped_query, items_df$title, ignore.case = TRUE)
    content_match <- grepl(escaped_query, items_df$content, ignore.case = TRUE)
    matches <- matches & (title_match | content_match)
  }
  
  # 2. Topic Filter
  topic_str <- trimws(as.character(topic))
  if (nzchar(topic_str) && tolower(topic_str) != "all") {
    matches <- matches & (tolower(trimws(items_df$topic)) == tolower(topic_str))
  }
  
  # 3. Item Type Filter
  type_str <- trimws(as.character(item_type))
  if (nzchar(type_str) && tolower(type_str) != "all") {
    matches <- matches & (tolower(trimws(items_df$item_type)) == tolower(type_str))
  }
  
  # 4. Importance Filter
  imp_str <- trimws(as.character(importance))
  if (nzchar(imp_str) && tolower(imp_str) != "all") {
    matches <- matches & (tolower(trimws(items_df$importance)) == tolower(imp_str))
  }
  
  # 5. Tag Filter: item's tag set must contain the selected tag
  tag_str <- normalize_tag(tag)
  if (nzchar(tag_str) && tag_str != "all") {
    tag_matches <- vapply(items_df$tags, function(t_str) {
      item_tags <- parse_tags(t_str)
      return(tag_str %in% item_tags)
    }, FUN.VALUE = logical(1), USE.NAMES = FALSE)
    matches <- matches & tag_matches
  }
  
  res <- items_df[matches, , drop = FALSE]
  if (nrow(res) == 0) return(res)
  
  # Sorting
  sort_by <- tolower(trimws(sort_by))
  sort_dir <- tolower(trimws(sort_dir))
  decreasing <- (sort_dir != "asc")
  
  if (sort_by == "title") {
    order_idx <- order(tolower(res$title), decreasing = decreasing)
  } else if (sort_by == "created_at") {
    order_idx <- order(res$created_at, decreasing = decreasing)
  } else if (sort_by == "importance") {
    imp_levels <- c("Low" = 1, "Medium" = 2, "High" = 3)
    scores <- unname(imp_levels[res$importance])
    scores[is.na(scores)] <- 0
    order_idx <- order(scores, decreasing = decreasing)
  } else {
    # Default: updated_at
    order_idx <- order(res$updated_at, decreasing = decreasing)
  }
  
  res <- res[order_idx, , drop = FALSE]
  rownames(res) <- NULL
  return(res)
}

# ------------------------------------------------------------------------------
# 6. Related Notes Discovery (Tag-Based Deterministic Overlap)
# ------------------------------------------------------------------------------

#' Calculate related notes for a given target note using tag overlap and Jaccard similarity
#'
#' Scoring method:
#' - Tag set A = tags(target note)
#' - Tag set B = tags(candidate note)
#' - Shared tags S = A intersect B
#' - If |S| == 0: relatedness is 0 (excluded)
#' - Jaccard index: |S| / |A union B|
#' - Tag rarity weight: tags appearing in fewer items in the collection have higher specificity.
#'   weight(t) = 1 + log((N + 1) / (freq(t) + 1))
#'   score = round( (sum(weights of S) / sum(weights of A union B)) * 100 )
#' - Candidate note == target note is strictly excluded.
calculate_related_notes <- function(target_id, items_df, max_results = 5) {
  if (is.null(items_df) || nrow(items_df) == 0) {
    return(list(
      target_id = target_id,
      target_tags = character(0),
      count = 0,
      notes = list(),
      message = "No notes exist in the library."
    ))
  }
  
  target_idx <- which(items_df$id == target_id)
  if (length(target_idx) == 0) {
    return(list(
      target_id = target_id,
      target_tags = character(0),
      count = 0,
      notes = list(),
      message = paste0("Target note '", target_id, "' was not found.")
    ))
  }
  
  target_row <- items_df[target_idx[1], ]
  target_tags <- parse_tags(target_row$tags)
  
  if (length(target_tags) == 0) {
    return(list(
      target_id = target_id,
      target_title = target_row$title,
      target_tags = character(0),
      count = 0,
      notes = list(),
      message = "This note has no tags assigned. Add tags to enable related note discovery."
    ))
  }
  
  # Calculate global tag frequencies across the collection
  all_item_tags <- lapply(items_df$tags, parse_tags)
  all_tags_flat <- unlist(all_item_tags)
  tag_freq_table <- table(all_tags_flat)
  total_notes <- nrow(items_df)
  
  # Function to get rarity weight for a tag
  get_tag_weight <- function(t) {
    freq <- if (t %in% names(tag_freq_table)) as.numeric(tag_freq_table[[t]]) else 1
    1 + log((total_notes + 1) / (freq + 1))
  }
  
  candidate_results <- list()
  
  for (i in seq_len(nrow(items_df))) {
    cand_id <- items_df$id[i]
    if (cand_id == target_id) next # Exclude target note itself
    
    cand_tags <- all_item_tags[[i]]
    if (length(cand_tags) == 0) next
    
    # Set operations
    shared_tags <- intersect(target_tags, cand_tags)
    if (length(shared_tags) == 0) next
    
    union_tags <- union(target_tags, cand_tags)
    
    # Weighted Jaccard
    shared_weight <- sum(vapply(shared_tags, get_tag_weight, numeric(1)))
    union_weight <- sum(vapply(union_tags, get_tag_weight, numeric(1)))
    
    score <- if (union_weight > 0) round((shared_weight / union_weight) * 100) else 0
    raw_jaccard <- round((length(shared_tags) / length(union_tags)) * 100)
    
    # Build human-readable deterministic explanation
    shared_str <- paste(paste0("'", shared_tags, "'"), collapse = ", ")
    reason <- sprintf(
      "Shares %d tag%s (%s) — %d%% weighted tag overlap (%d%% Jaccard index).",
      length(shared_tags),
      if (length(shared_tags) > 1) "s" else "",
      shared_str,
      score,
      raw_jaccard
    )
    
    candidate_results[[length(candidate_results) + 1]] <- list(
      id = cand_id,
      title = items_df$title[i],
      item_type = items_df$item_type[i],
      topic = items_df$topic[i],
      importance = items_df$importance[i],
      tags = cand_tags,
      shared_tags = shared_tags,
      score = score,
      raw_jaccard = raw_jaccard,
      reason = reason,
      updated_at = items_df$updated_at[i]
    )
  }
  
  if (length(candidate_results) == 0) {
    return(list(
      target_id = target_id,
      target_title = target_row$title,
      target_tags = target_tags,
      count = 0,
      notes = list(),
      message = "No related notes share tags with this item. Try tagging related concepts with overlapping keywords."
    ))
  }
  
  # Sort descending by score, then shared tag count, then updated_at
  scores <- vapply(candidate_results, function(x) x$score, numeric(1))
  shared_counts <- vapply(candidate_results, function(x) length(x$shared_tags), integer(1))
  updated_dates <- vapply(candidate_results, function(x) x$updated_at, character(1))
  
  order_idx <- order(scores, shared_counts, updated_dates, decreasing = TRUE)
  sorted_results <- candidate_results[order_idx]
  
  if (length(sorted_results) > max_results) {
    sorted_results <- sorted_results[1:max_results]
  }
  
  return(list(
    target_id = target_id,
    target_title = target_row$title,
    target_tags = target_tags,
    count = length(sorted_results),
    notes = sorted_results,
    message = sprintf("Found %d related note%s based on tag overlap.", length(sorted_results), if (length(sorted_results) > 1) "s" else "")
  ))
}

# ------------------------------------------------------------------------------
# 7. Dashboard Summary Statistics
# ------------------------------------------------------------------------------

#' Aggregate high-level overview metrics for the dashboard
get_dashboard_summary <- function(items_df) {
  if (is.null(items_df) || nrow(items_df) == 0) {
    return(list(
      total_items = 0,
      by_topic = list(),
      by_type = list(),
      by_importance = list(High = 0, Medium = 0, Low = 0),
      top_tags = list(),
      recent_items = list()
    ))
  }
  
  # By topic
  topics <- items_df$topic[nzchar(trimws(items_df$topic))]
  topic_counts <- as.list(table(topics))
  
  # By type
  types <- items_df$item_type[nzchar(trimws(items_df$item_type))]
  type_counts <- as.list(table(types))
  
  # By importance
  imp_table <- table(factor(items_df$importance, levels = c("High", "Medium", "Low")))
  imp_counts <- as.list(imp_table)
  
  # Frequently used tags
  all_tags <- unlist(lapply(items_df$tags, parse_tags))
  if (length(all_tags) > 0) {
    tag_freq <- sort(table(all_tags), decreasing = TRUE)
    top_n <- min(12, length(tag_freq))
    top_tags <- lapply(seq_len(top_n), function(i) {
      list(tag = names(tag_freq)[i], count = as.integer(tag_freq[i]))
    })
  } else {
    top_tags <- list()
  }
  
  # Recently updated items (top 5)
  order_rec <- order(items_df$updated_at, decreasing = TRUE)
  recent_idx <- head(order_rec, 5)
  recent_items <- lapply(recent_idx, function(i) {
    list(
      id = items_df$id[i],
      title = items_df$title[i],
      item_type = items_df$item_type[i],
      topic = items_df$topic[i],
      importance = items_df$importance[i],
      tags = parse_tags(items_df$tags[i]),
      updated_at = items_df$updated_at[i]
    )
  })
  
  list(
    total_items = nrow(items_df),
    by_topic = topic_counts,
    by_type = type_counts,
    by_importance = imp_counts,
    top_tags = top_tags,
    recent_items = recent_items
  )
}
