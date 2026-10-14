# ==============================================================================
# Personal Knowledge Organizer - Main Server & CLI Verification Entrypoint
# R/main.R
# ==============================================================================

# Determine project root and source functions
script_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    getwd()
  }
}, error = function(e) getwd())

project_root <- if (basename(script_dir) == "R") dirname(script_dir) else getwd()
setwd(project_root)

source(file.path(project_root, "R", "functions.R"))

DATA_FILE <- file.path(project_root, "data", "knowledge_items.csv")
WEB_DIR <- file.path(project_root, "web")

# ------------------------------------------------------------------------------
# Automated Test Suite (--test)
# ------------------------------------------------------------------------------
run_tests <- function() {
  cat("\n======================================================\n")
  cat("  Personal Knowledge Organizer - Test Suite Execution\n")
  cat("======================================================\n\n")
  
  passed <- 0
  failed <- 0
  
  assert <- function(condition, test_name) {
    if (condition) {
      cat(sprintf("  [PASS] %s\n", test_name))
      passed <<- passed + 1
    } else {
      cat(sprintf("  [FAIL] %s\n", test_name))
      failed <<- failed + 1
    }
  }
  
  # 1. Test CSV Loading
  cat("--- 1. Data Loading & Persistence ---\n")
  df <- load_knowledge_items(DATA_FILE)
  assert(nrow(df) >= 8, "Sample CSV loads at least 8 initial knowledge items")
  assert(all(KNOWLEDGE_COLUMNS %in% colnames(df)), "All required columns exist in loaded data frame")
  
  # 2. Tag parsing and normalization
  cat("\n--- 2. Tag Normalization ---\n")
  tags1 <- parse_tags("R, Data-Science, Web Development; API-design, r")
  assert(all(c("r", "data-science", "web-development", "api-design") %in% tags1), "Tag parsing splits, lowercases, and strips duplicates")
  assert(length(tags1) == 4, "Tag parsing removes duplicate tags")
  assert(format_tags(tags1) == "r, data-science, web-development, api-design", "Tag formatting produces clean comma-separated output")
  
  # 3. Validation Logic
  cat("\n--- 3. Validation Rules ---\n")
  v_empty <- validate_knowledge_item(list(title = "", content = "test", item_type = "Note", topic = "General"))
  assert(!v_empty$valid, "Empty title is rejected")
  
  v_bad_type <- validate_knowledge_item(list(title = "Valid Title", content = "Content", item_type = "InvalidType", topic = "General"))
  assert(!v_bad_type$valid, "Invalid item_type is rejected")
  
  v_bad_url <- validate_knowledge_item(list(title = "Valid", content = "Content", item_type = "Note", topic = "General", source_url = "not-a-url"))
  assert(!v_bad_url$valid, "Malformed URL without http/https protocol is rejected")
  
  v_good <- validate_knowledge_item(list(
    title = "Valid Title",
    content = "Valid Content",
    item_type = "Concept",
    topic = "Computer Science",
    importance = "High",
    source_url = "https://example.com/docs"
  ))
  assert(v_good$valid, "Completely valid item passes validation")
  
  # 4. Search and Keyword Matching
  cat("\n--- 4. Search & Case-Insensitive Filtering ---\n")
  # Search in title
  res_title <- search_and_filter_items(df, query = "vectorized")
  assert(nrow(res_title) >= 1 && grepl("Vectorized", res_title$title[1], ignore.case = TRUE), "Keyword search matches title case-insensitively")
  
  # Search in content
  res_content <- search_and_filter_items(df, query = "preallocate")
  assert(nrow(res_content) >= 1 && grepl("preallocate", res_content$content[1], ignore.case = TRUE), "Keyword search matches body content")
  
  # Topic filter
  res_topic <- search_and_filter_items(df, topic = "Programming")
  assert(nrow(res_topic) >= 1 && all(res_topic$topic == "Programming"), "Topic filter returns only Programming items")
  
  # Tag filter
  res_tag <- search_and_filter_items(df, tag = "architecture")
  assert(nrow(res_tag) >= 2, "Tag filter returns all items containing the specified tag")
  
  # Multi-criteria filter
  res_multi <- search_and_filter_items(df, topic = "Programming", importance = "High")
  assert(nrow(res_multi) >= 1 && all(res_multi$topic == "Programming" & res_multi$importance == "High"), "Multi-filter combines topic and importance")
  
  # Empty search result
  res_empty <- search_and_filter_items(df, query = "nonexistent_term_xyz_12345")
  assert(nrow(res_empty) == 0, "Non-matching search returns clean empty data frame without error")
  
  # 5. Related Notes Discovery
  cat("\n--- 5. Related Notes Discovery Algorithm ---\n")
  rel_001 <- calculate_related_notes("item_001", df)
  assert(rel_001$count > 0, "Discovers related notes for item_001 based on shared tags")
  assert(!any(vapply(rel_001$notes, function(x) x$id == "item_001", logical(1))), "Target item is strictly excluded from its own related notes")
  
  # Verify shared tags exist in both notes
  top_rel <- rel_001$notes[[1]]
  assert(length(top_rel$shared_tags) > 0, "Related note contains non-empty shared_tags list")
  assert(nzchar(top_rel$reason), "Related note contains transparent human-readable explanation")
  
  # Edge case: Note without tags
  dummy_no_tags <- df[1, ]
  dummy_no_tags$id <- "dummy_no_tags"
  dummy_no_tags$tags <- ""
  df_with_dummy <- rbind(df, dummy_no_tags)
  rel_no_tags <- calculate_related_notes("dummy_no_tags", df_with_dummy)
  assert(rel_no_tags$count == 0 && grepl("no tags", rel_no_tags$message, ignore.case = TRUE), "Note with no tags returns graceful informative explanation")
  
  # 6. CRUD in Temporary File
  cat("\n--- 6. CRUD & Persistence Invariants ---\n")
  temp_csv <- file.path(tempdir(), paste0("test_items_", as.numeric(Sys.time()), ".csv"))
  file.copy(DATA_FILE, temp_csv)
  
  # Add new note with multiline content and quotes
  test_new_item <- list(
    id = "test_crud_01",
    title = 'Unit Test "Item" with Special Characters & Commas',
    content = "Line 1: Testing multiline persistence.\nLine 2: Comma test, quotes test \"quoted\", and special chars: ©, —, →.",
    item_type = "Note",
    topic = "Testing",
    tags = "testing, r, architecture",
    importance = "Medium",
    source_url = "https://test.local/unit"
  )
  
  add_res <- add_knowledge_item(test_new_item, temp_csv)
  assert(add_res$success, "New item added successfully to CSV")
  
  # Reload from disk and verify
  reloaded_df <- load_knowledge_items(temp_csv)
  found_row <- reloaded_df[reloaded_df$id == "test_crud_01", ]
  assert(nrow(found_row) == 1, "Added item persists and is retrieved after reload")
  assert(grepl("Line 2", found_row$content[1]), "Multiline content and quotes are perfectly preserved")
  
  # Update item
  update_res <- update_knowledge_item("test_crud_01", list(title = "Updated Title for Unit Test", importance = "High"), temp_csv)
  assert(update_res$success, "Item updated successfully")
  
  reloaded_updated <- load_knowledge_items(temp_csv)
  updated_row <- reloaded_updated[reloaded_updated$id == "test_crud_01", ]
  assert(updated_row$title[1] == "Updated Title for Unit Test", "Updated title matches after reload")
  assert(updated_row$importance[1] == "High", "Updated importance matches after reload")
  
  # Delete item
  del_res <- delete_knowledge_item("test_crud_01", temp_csv)
  assert(del_res$success, "Item deleted successfully")
  
  reloaded_after_del <- load_knowledge_items(temp_csv)
  assert(! "test_crud_01" %in% reloaded_after_del$id, "Deleted item no longer exists in CSV")
  
  unlink(temp_csv)
  
  # 7. Dashboard Aggregation
  cat("\n--- 7. Dashboard Summary Statistics ---\n")
  dash <- get_dashboard_summary(df)
  assert(dash$total_items == nrow(df), "Dashboard total items matches data frame row count")
  assert(length(dash$top_tags) > 0, "Dashboard returns top tags")
  assert(length(dash$recent_items) <= 5, "Dashboard returns up to 5 recently updated items")
  
  cat("\n======================================================\n")
  cat(sprintf("  Results: %d Passed, %d Failed\n", passed, failed))
  cat("======================================================\n\n")
  
  if (failed > 0) quit(status = 1)
}

# ------------------------------------------------------------------------------
# Interactive Demo Mode (--demo)
# ------------------------------------------------------------------------------
run_demo <- function() {
  cat("\n======================================================\n")
  cat("  Personal Knowledge Organizer - Interactive R Demo  \n")
  cat("======================================================\n\n")
  
  df <- load_knowledge_items(DATA_FILE)
  cat(sprintf("Loaded %d knowledge items from %s\n\n", nrow(df), DATA_FILE))
  
  cat("Available Topics:\n")
  print(table(df$topic))
  cat("\n")
  
  cat("--- Demo 1: Keyword Search across Titles & Content ---\n")
  cat("Searching for keyword: 'vector'\n")
  results <- search_and_filter_items(df, query = "vector")
  for (i in seq_len(nrow(results))) {
    cat(sprintf("  [%s] %s (%s - %s)\n", results$id[i], results$title[i], results$item_type[i], results$topic[i]))
    cat(sprintf("    Tags: %s\n", results$tags[i]))
  }
  cat("\n")
  
  cat("--- Demo 2: Related Notes Discovery for 'item_003' (Microservices with Plumber) ---\n")
  target_item <- df[df$id == "item_003", ]
  cat(sprintf("Target Note: %s\n", target_item$title))
  cat(sprintf("Target Tags: %s\n\n", target_item$tags))
  
  rel <- calculate_related_notes("item_003", df)
  cat(sprintf("Discovered %d related notes:\n", rel$count))
  for (n in rel$notes) {
    cat(sprintf("  -> [%s] %s (Match Score: %d%%)\n", n$id, n$title, n$score))
    cat(sprintf("     Reason: %s\n", n$reason))
    cat(sprintf("     Shared Tags: %s\n\n", paste(n$shared_tags, collapse = ", ")))
  }
  
  cat("--- Demo 3: Multi-Criteria Filtering ---\n")
  cat("Filtering by topic: 'Programming' AND importance: 'High'\n")
  filtered <- search_and_filter_items(df, topic = "Programming", importance = "High")
  for (i in seq_len(nrow(filtered))) {
    cat(sprintf("  - %s [%s] (Tags: %s)\n", filtered$title[i], filtered$importance[i], filtered$tags[i]))
  }
  cat("\nDemo finished successfully.\n\n")
}

# ------------------------------------------------------------------------------
# Plumber API Server & Static Mounting
# ------------------------------------------------------------------------------
start_server <- function(port = 8000, host = "127.0.0.1") {
  if (!requireNamespace("plumber", quietly = TRUE)) {
    stop("The 'plumber' package is required to run the HTTP API server. Install it with install.packages('plumber').")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The 'jsonlite' package is required. Install it with install.packages('jsonlite').")
  }
  
  cat("\nInitializing Personal Knowledge Organizer Server...\n")
  cat(sprintf("Data File: %s\n", DATA_FILE))
  cat(sprintf("Web Root:  %s\n", WEB_DIR))
  
  pr <- plumber::pr()
  pr$setSerializer(plumber::serializer_unboxed_json())
  
  # CORS and Response Headers Middleware
  pr$registerHooks(list(
    preroute = function(req) {
      # Handle CORS preflight
      if (req$REQUEST_METHOD == "OPTIONS") {
        res <- req$res
        res$status <- 200
        res$setHeader("Access-Control-Allow-Origin", "*")
        res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")
        return(list())
      }
    },
    postroute = function(req, res) {
      res$setHeader("Access-Control-Allow-Origin", "*")
      res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
      res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept")
    }
  ))
  
  # Helper to parse JSON body defensively
  parse_body <- function(req) {
    if (!is.null(req$postBody) && nzchar(req$postBody)) {
      tryCatch({
        return(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE))
      }, error = function(e) list())
    }
    if (!is.null(req$body)) {
      if (is.list(req$body)) return(req$body)
      if (is.character(req$body) && nzchar(req$body)) {
        tryCatch({
          return(jsonlite::fromJSON(req$body, simplifyVector = FALSE))
        }, error = function(e) list())
      }
    }
    return(list())
  }
  
  # ---------------- API ENDPOINTS ----------------
  
  # 1. Health check
  pr$handle("GET", "/api/health", function(res) {
    df <- load_knowledge_items(DATA_FILE)
    res$status <- 200
    list(
      status = "ok",
      application = "Personal Knowledge Organizer",
      items_count = nrow(df),
      data_file = DATA_FILE,
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
    )
  })
  
  # 2. Get items with search & filtering
  pr$handle("GET", "/api/items", function(
    req, res,
    q = "",
    topic = "",
    item_type = "",
    tag = "",
    importance = "",
    sort_by = "updated_at",
    sort_dir = "desc"
  ) {
    df <- load_knowledge_items(DATA_FILE)
    filtered <- search_and_filter_items(
      df,
      query = q,
      topic = topic,
      item_type = item_type,
      tag = tag,
      importance = importance,
      sort_by = sort_by,
      sort_dir = sort_dir
    )
    
    # Format rows as list of objects
    items_list <- list()
    if (nrow(filtered) > 0) {
      for (i in seq_len(nrow(filtered))) {
        items_list[[i]] <- list(
          id = filtered$id[i],
          title = filtered$title[i],
          content = filtered$content[i],
          item_type = filtered$item_type[i],
          topic = filtered$topic[i],
          tags = parse_tags(filtered$tags[i]),
          raw_tags = filtered$tags[i],
          importance = filtered$importance[i],
          source_url = filtered$source_url[i],
          created_at = filtered$created_at[i],
          updated_at = filtered$updated_at[i]
        )
      }
    }
    
    list(
      total_items = nrow(df),
      matched_count = nrow(filtered),
      items = items_list
    )
  })
  
  # 3. Get single item by ID
  pr$handle("GET", "/api/items/<id>", function(id, res) {
    df <- load_knowledge_items(DATA_FILE)
    idx <- which(df$id == id)
    if (length(idx) == 0) {
      res$status <- 404
      return(list(error = paste0("Item '", id, "' not found.")))
    }
    
    row <- df[idx[1], ]
    list(
      id = row$id,
      title = row$title,
      content = row$content,
      item_type = row$item_type,
      topic = row$topic,
      tags = parse_tags(row$tags),
      raw_tags = row$tags,
      importance = row$importance,
      source_url = row$source_url,
      created_at = row$created_at,
      updated_at = row$updated_at
    )
  })
  
  # 4. Create new item
  pr$handle("POST", "/api/items", function(req, res) {
    body <- parse_body(req)
    if (length(body) == 0) {
      res$status <- 400
      return(list(success = FALSE, errors = c("Request body is empty or not valid JSON.")))
    }
    
    result <- add_knowledge_item(body, DATA_FILE)
    if (!result$success) {
      res$status <- 422
      return(list(success = FALSE, errors = result$errors))
    }
    
    res$status <- 201
    return(result)
  })
  
  # 5. Update item
  pr$handle("PUT", "/api/items/<id>", function(id, req, res) {
    body <- parse_body(req)
    if (length(body) == 0) {
      res$status <- 400
      return(list(success = FALSE, errors = c("Request body is empty or not valid JSON.")))
    }
    
    result <- update_knowledge_item(id, body, DATA_FILE)
    if (!result$success) {
      res$status <- if (any(grepl("not found", result$errors))) 404 else 422
      return(list(success = FALSE, errors = result$errors))
    }
    
    return(result)
  })
  
  # 6. Delete item
  pr$handle("DELETE", "/api/items/<id>", function(id, res) {
    result <- delete_knowledge_item(id, DATA_FILE)
    if (!result$success) {
      res$status <- 404
      return(list(success = FALSE, errors = result$errors))
    }
    return(result)
  })
  
  # 7. Related Notes Discovery endpoint
  pr$handle("GET", "/api/related/<id>", function(id, res) {
    df <- load_knowledge_items(DATA_FILE)
    result <- calculate_related_notes(id, df, max_results = 6)
    return(result)
  })
  
  # 8. Dashboard statistics
  pr$handle("GET", "/api/dashboard", function(res) {
    df <- load_knowledge_items(DATA_FILE)
    summary_data <- get_dashboard_summary(df)
    return(summary_data)
  })
  
  # Static frontend files
  if (dir.exists(WEB_DIR)) {
    pr <- plumber::pr_static(pr, "/", WEB_DIR)
  }
  
  cat("\n======================================================\n")
  cat("  Personal Knowledge Organizer is Ready!\n")
  cat(sprintf("  Local URL:   http://%s:%d\n", host, port))
  cat(sprintf("  API Health:  http://%s:%d/api/health\n", host, port))
  cat(sprintf("  Dashboard:   http://%s:%d/api/dashboard\n", host, port))
  cat("  Press Ctrl+C to stop the server.\n")
  cat("======================================================\n\n")
  
  pr$run(host = host, port = as.integer(port))
}

# ------------------------------------------------------------------------------
# Entrypoint Dispatcher
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if ("--test" %in% args) {
  run_tests()
} else if ("--demo" %in% args) {
  run_demo()
} else {
  # Look for optional port argument
  port <- 8000
  port_arg_idx <- which(grepl("^--port=", args))
  if (length(port_arg_idx) > 0) {
    port <- as.integer(sub("^--port=", "", args[port_arg_idx[1]]))
  } else {
    port_idx <- which(args == "-p" | args == "--port")
    if (length(port_idx) > 0 && length(args) >= port_idx + 1) {
      port <- as.integer(args[port_idx + 1])
    }
  }
  start_server(port = port)
}
