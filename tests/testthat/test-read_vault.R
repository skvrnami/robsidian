test_df1 <- dplyr::tribble(
    ~doc_id, ~text, ~full_path,
    "test", "testing", "~/vault/a/",
    "test", "testing 2", "~/vault/b/"
)

test_df2 <- dplyr::tribble(
    ~doc_id, ~text, ~full_path,
    "test", "testing", "~/vault/a/test/",
    "test", "testing 2", "~/vault/b/test/",
    "test2", "testing", "~/vault/a/",
    "test2", "testing 2", "~/vault/b/"
)

test_df3 <- dplyr::tribble(
    ~doc_id, ~text, ~full_path,
    "test", "testing", "~/vault/a/test/",
    "test", "testing 2", "~/vault/b/test/",
    "test", "testing 3", "~/vault/a/"
)

test_that("test resolving duplicated doc IDs", {
  expect_equal(resolve_duplicated_doc_ids(test_df1)$doc_id, c("a/test", "b/test"))
  expect_equal(resolve_duplicated_doc_ids(test_df2)$doc_id,
               c("a/test/test", "b/test/test", "a/test2", "b/test2"))
  expect_equal(resolve_duplicated_doc_ids(test_df3)$doc_id,
               c("a/test/test", "b/test/test", "a/test"))
})
