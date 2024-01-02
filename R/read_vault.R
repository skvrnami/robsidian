
remove_last_part <- function(x){
    purrr::map2(x, names(x), function(y, name) {
        len_y <- length(y)
        y <- y[1:(len_y - 1)]
        y
    })

}

find_smallest_unique_substring_recurse <- function(paths){
    if(length(unique(names(paths))) == length(paths)){
        names(paths)
    }else{
        removed_last_part <- remove_last_part(paths)
        last_part <- purrr::map_chr(removed_last_part, ~tail(.x, 1))
        names(removed_last_part) <- ifelse(last_part == "", names(removed_last_part),
                                            paste0(last_part, "/", names(removed_last_part)))
        if(length(unique(names(removed_last_part))) != length(names(removed_last_part))){
            counts <- table(names(removed_last_part))
            unique_path <- names(counts[counts == 1])
            which_unique <- which(names(removed_last_part) %in% unique_path)
            if(length(which_unique)) removed_last_part[[which_unique]] <- ""
        }
        find_smallest_unique_substring_recurse(removed_last_part)
    }
}

find_smallest_unique_substring <- function(paths){
    spl_paths <- strsplit(paths, "/")
    names(spl_paths) <- purrr::map_chr(spl_paths, ~tail(.x, 1))

    find_smallest_unique_substring_recurse(spl_paths)
}

# when doc_id is duplicated insert folder path from full_path column into doc_id
resolve_duplicated_doc_ids <- function(df){
    not_duplicated <- df |>
        dplyr::group_by(doc_id) |>
        dplyr::filter(dplyr::n() == 1) |>
        dplyr::ungroup()

    duplicated <- df |>
        dplyr::group_by(doc_id) |>
        dplyr::filter(dplyr::n() > 1) |>
        dplyr::ungroup()

    groups <- unique(duplicated$doc_id)
    deduplicated <- purrr::map_df(groups, function(x) {
        group_docs <- duplicated |>
          dplyr::filter(doc_id == x) |>
          dplyr::mutate(full_path = paste0(full_path, doc_id))

        unique_doc_id <- find_smallest_unique_substring(group_docs$full_path)

        group_docs |>
          dplyr::mutate(doc_id = unique_doc_id)

    })

    dplyr::bind_rows(not_duplicated, deduplicated)
}

#' Reads all notes from Obsidian vault
#'
#' @param path Path to the Obsidian vault
#'
#' Reads only .md and .canvas files
#' @export
read_vault <- function(path){
    files <- list.files(path, pattern = "(.md|.canvas)$",
                        full.names = TRUE, recursive = TRUE)

    out <- purrr::map_df(files, function(x) readtext::readtext(x, verbosity = 0)) |>
      dplyr::mutate(file_name = doc_id,
                    full_path = purrr::map2_chr(doc_id, files, function(x, y) gsub(x, "", y))) |>
      dplyr::mutate(doc_id = gsub("\\.(md)$", "", file_name)) |>
      dplyr::select(-file_name)

    if(anyDuplicated(out$doc_id)){
        out <- resolve_duplicated_doc_ids(out)
    }

    out
}

get_wikilinks <- function(x){
  unlist(stringr::str_extract_all(x, pattern = "\\[\\[[^\\[]+\\]\\]")) |>
    gsub("(\\[\\[|\\]\\])", "", x = _) |>
    gsub("(#|\\|){1}[^#|]+$", "", x = _)
}

#' Create tidygraph from vault
#'
#' @param vault Loaded Obsidian vault
#'
#' @export
create_graph <- function(vault){
  vault_wikilinks <- vault |>
    dplyr::mutate(wikilinks = purrr::map(text, get_wikilinks)) |>
    tidyr::unnest(wikilinks)

  notes <- data.frame(
      name = unique(c(vault_wikilinks$doc_id, vault_wikilinks$wikilinks))) |>
      dplyr::mutate(id = dplyr::row_number())
  edges <- vault_wikilinks |>
      dplyr::select(doc_id, wikilinks) |>
      dplyr::left_join(x = _, notes |> dplyr::rename(from = id), by = c("doc_id"="name")) |>
      dplyr::left_join(x = _, notes |> dplyr::rename(to = id), by = c("wikilinks"="name"))

  tidygraph::tbl_graph(nodes = notes,
            edges = edges)
}
