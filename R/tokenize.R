#' Tokenization of character variables
#'
#' `step_tokenize` creates a *specification* of a recipe step that
#'  will convert a character predictor into a list of its tokenized
#'  parts.
#'
#' @param recipe A recipe object. The step will be added to the
#'  sequence of operations for this recipe.
#' @param ... One or more selector functions to choose variables.
#'  For `step_tokenize`, this indicates the variables to be encoded
#'  into a list column. See [recipes::selections()] for more
#'  details. For the `tidy` method, these are not currently used.
#' @param role Not used by this step since no new variables are
#'  created.
#' @param columns A list of tibble results that define the
#'  encoding. This is `NULL` until the step is trained by
#'  [recipes::prep.recipe()].
#' @param options A list of options passed to the tokenizer.
#' @param token Unit for tokenizing. Built-in options from the 
#'  [tokenizers] package are "words" (default), "characters",
#'  "character_shingles", "ngrams", "skip_ngrams", "sentences", 
#'  "lines", "paragraphs", "regex", "tweets" (tokenization by 
#'  word that preserves usernames, hashtags, and URLS ),  "ptb" 
#'  (Penn Treebank), "skip_ngrams" and  "word_stems".
#' @param custom.token User supplied tokenizer. use of this argument
#'  will overwrite the token argument. Must take a character vector
#'  as input and output a list of character vectors. 
#' @param skip A logical. Should the step be skipped when the
#'  recipe is baked by [recipes::bake.recipe()]? While all
#'  operations are baked when [recipes::prep.recipe()] is run, some
#'  operations may not be able to be conducted on new data (e.g.
#'  processing the outcome variable(s)). Care should be taken when
#'  using `skip = TRUE` as it may affect the computations for
#'  subsequent operations
#' @param trained A logical to indicate if the recipe has been
#'  baked.
#' @return An updated version of `recipe` with the new step added
#'  to the sequence of existing steps (if any).
#' @examples
#' library(recipes)
#' 
#' data(okc_text)
#' 
#' okc_rec <- recipe(~ ., data = okc_text) %>%
#'   step_tokenize(essay0) %>%
#'   prep(training = okc_text, retain = TRUE)
#' 
#' juice(okc_rec, essay0) %>%
#'   slice(1:2)
#' 
#' juice(okc_rec) %>%
#'   slice(2) %>%
#'   pull(essay0)
#'   
#' okc_rec_chars <- recipe(~ ., data = okc_text) %>%
#'   step_tokenize(essay0, token = "characters") %>%
#'   prep(training = okc_text, retain = TRUE)
#' 
#' juice(okc_rec_chars) %>%
#'   slice(2) %>%
#'   pull(essay0)
#' @keywords datagen 
#' @concept preprocessing encoding
#' @export
#' @importFrom recipes add_step step terms_select sel2char ellipse_check 
#' @importFrom recipes check_type
step_tokenize <-
  function(recipe,
           ...,
           role = NA,
           trained = FALSE,
           columns = NULL,
           options = list(),
           token = "words",
           custom.token = NULL,
           skip = FALSE
  ) {
    add_step(
      recipe,
      step_tokenize_new(
        terms = ellipse_check(...),
        role = role,
        trained = trained,
        columns = columns,
        options = options,
        token = token,
        custom.token = custom.token,
        skip = skip
      )
    )
  }

step_tokenize_new <-
  function(terms = NULL,
           role = NA,
           trained = FALSE,
           columns = NULL,
           options = NULL,
           token = NULL,
           custom.token = NULL,
           skip = FALSE) {
    step(
      subclass = "tokenize",
      terms = terms,
      role = role,
      trained = trained,
      columns = columns,
      options = options,
      token = token,
      custom.token = custom.token,
      skip = skip
    )
  }

#' @export
prep.step_tokenize <- function(x, training, info = NULL, ...) {
  col_names <- terms_select(x$terms, info = info)
  
  training <- factor_to_text(training, col_names)
  
  check_type(training[, col_names], quant = FALSE)
  
  step_tokenize_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    columns = col_names,
    options = x$options,
    token = x$token,
    custom.token = x$custom.token,
    skip = x$skip
  )
}

#' @export
#' @importFrom tibble as_tibble
#' @importFrom recipes bake prep
bake.step_tokenize <- function(object, newdata, ...) {
  col_names <- object$columns
  # for backward compat
  
  tokenizer <- null_switch(object$custom.token, 
                           tokenizers_switch(object$token))

  for (i in seq_along(col_names)) {
    newdata[, col_names[i]] <- tokenizer_fun(newdata[, col_names[i]], 
                                             col_names[i],
                                             options = object$options,
                                             token = tokenizer)
  }
  as_tibble(newdata)
}

#' @importFrom rlang expr
tokenizer_fun <- function(data, name, options, token, ...) {
  check_type(data[, name], quant = FALSE)
  
  data <- factor_to_text(data, name)
  
  token_expr <- expr(
    token(
      x = data[, 1, drop = TRUE]
    )
  )
    
  if (length(options) > 0)
    token_expr <- mod_call_args(token_expr, args = options)
  
  out <- tibble::tibble(eval(token_expr))
  names(out) <- name
  out
}

tokenizers_switch <- function(name) {
  possible_tokenizers <- 
    c("characters", "character_shingle", "lines", "ngrams",
      "paragraphs", "ptb", "regex", "sentences", "skip_ngrams",
      "tweets", "words", "word_stems")
  
  if(!(name %in% possible_tokenizers)) 
    stop("token should be one of the supported ",
         paste0("'", possible_tokenizers, "'", collapse = ", "),
         call. = FALSE)
  
  switch(name,
         characters = tokenizers::tokenize_characters,
         character_shingle = tokenizers::tokenize_character_shingles,
         lines = tokenizers::tokenize_lines,
         ngrams = tokenizers::tokenize_ngrams,
         paragraphs = tokenizers::tokenize_paragraphs,
         ptb = tokenizers::tokenize_ptb,
         regex = tokenizers::tokenize_regex,
         sentences = tokenizers::tokenize_sentences,
         skip_ngrams = tokenizers::tokenize_skip_ngrams,
         tweets = tokenizers::tokenize_tweets,
         words = tokenizers::tokenize_words,
         word_stems = tokenizers::tokenize_word_stems
  )
}
