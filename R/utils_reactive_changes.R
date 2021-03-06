#' Reactive Changes
#'
#' Create a reactive that is only updated when the expression returns a different vector to what is currently stored
#'
#' @param expr an expression that gets the values to observe whether they are changing
#'
#' @import shiny
#' @import rlang
#'
#' @return a reactiveVal
reactive_changes <- function(expr) {
  env <- parent.frame()
  mask <- new_data_mask(env)
  expr <- enquo(expr)
  rv <- reactiveVal()
  observe({
    nv <- eval_tidy(expr, mask)
    ov <- rv()
    if (!(length(nv) == length(rv) && all(nv == ov))) {
      rv(nv)
    }
  })
  class(rv) <- c("reactive_changes", class(rv))
  invisible(rv)
}
