#' Plot top enriched genesets across multiple signatures
#'
#' @param multihyp_data A list of hyp objects
#' @param top Limit number of genesets shown
#' @param abrv Abbreviation length of genesetlabels
#' @param sizes Size dots by geneset sizes
#' @param pval_cutoff Filter results to be less than pval cutoff
#' @param fdr_cutoff Filter results to be less than fdr cutoff
#' @param val Choose significance value e.g. c("fdr", "pval")
#' @param title Plot title
#' @return A ggplot object
#'
#' @importFrom reshape2 melt
#' @importFrom magrittr %>% set_colnames
#' @importFrom dplyr filter select
#' @importFrom ggplot2 ggplot aes geom_point labs scale_color_continuous scale_size_continuous guides theme element_text element_blank
#' 
#' @keywords internal
.dots_multi_plot <- function(multihyp_data,
                             top=20,
                             abrv=50,
                             sizes=TRUE,
                             pval_cutoff=1, 
                             fdr_cutoff=1,
                             val=c("fdr", "pval"),
                             title="") {
    
    # Default arguments
    val <- match.arg(val)
    
    # Count significant genesets across signatures
    multihyp_dfs <- lapply(multihyp_data, function(hyp_obj) {
        hyp_obj$data %>%
        dplyr::filter(pval <= pval_cutoff) %>%
        dplyr::filter(fdr <= fdr_cutoff) %>%
        dplyr::select(label)
    })
    
    # Take top genesets
    labels <- names(sort(table(unlist(multihyp_dfs)), decreasing=TRUE))
    if (!is.null(top)) labels <- head(labels, top)
    
    # Handle empty dataframes
    if (length(labels) == 0) return(ggempty())
    
    # Create a multihyp dataframe
    dfs <- lapply(multihyp_data, function(hyp_obj) {
        hyp_df <- hyp_obj$data
        hyp_df[hyp_df$label %in% labels, c("label", val), drop=FALSE]
    })
    
    df <- suppressWarnings(Reduce(function(x, y) merge(x, y, by="label", all=TRUE), dfs))
    colnames(df) <- c("label", names(dfs))
    rownames(df) <- df$label
    df <- df[rev(labels), names(dfs)]
    
    # Abbreviate labels
    label.abrv <- substr(rownames(df), 1, abrv)
    if (any(duplicated(label.abrv))) {
        stop("Non-unique labels after abbreviating")
    } else {
        rownames(df) <- factor(label.abrv, levels=label.abrv)   
    }
    
    if (val == "pval") {
        cutoff <- pval_cutoff
        color.label <- "P-Value"
    }
    if (val == "fdr") {
        cutoff <- fdr_cutoff
        color.label <- "FDR"
    }
    
    df.melted <- reshape2::melt(as.matrix(df))
    colnames(df.melted) <- c("label", "signature", "significance")
    df.melted$size <- if(sizes) df.melted$significance else 1
    
    df.melted %>%
    dplyr::filter(significance <= cutoff) %>%
    ggplot(aes(x=signature, y=label, color=significance, size=size)) +
    geom_point() +
    scale_color_continuous(low="#114357", high="#E53935", trans=.reverselog_trans(10)) +
    scale_size_continuous(trans=.reverselog_trans(10), guide="none") +
    labs(title=title, color=color.label) +  
    theme(plot.title=element_text(hjust=0.5),
          axis.title.y=element_blank(),
          axis.title.x=element_blank(),
          axis.text.x=element_text(angle=45, hjust=1))
}

#' Plot top enriched genesets
#'
#' @param hyp_df A dataframe from a hyp object
#' @param top Limit number of genesets shown
#' @param abrv Abbreviation length of genesetlabels
#' @param sizes Size dots by geneset sizes
#' @param pval_cutoff Filter results to be less than pval cutoff
#' @param fdr_cutoff Filter results to be less than fdr cutoff
#' @param val Choose significance value e.g. c("fdr", "pval")
#' @param title Plot title
#' @return A ggplot object
#'
#' @importFrom purrr when
#' @importFrom dplyr filter
#' @importFrom ggplot2 ggplot aes geom_point labs scale_color_continuous scale_y_continuous guide_colorbar coord_flip geom_hline guides theme element_text element_blank
#' 
#' @keywords internal
.dots_plot <- function(hyp_df,
                       top=20,
                       abrv=50,
                       sizes=TRUE,
                       pval_cutoff=1, 
                       fdr_cutoff=1,
                       val=c("fdr", "pval"),
                       title="") {
    
    # Default arguments
    val <- match.arg(val)

    # Subset results
    df <- hyp_df %>%
          dplyr::filter(pval <= pval_cutoff) %>%
          dplyr::filter(fdr <= fdr_cutoff) %>%
          purrr::when(!is.null(top) ~ head(., top), ~ .)

    # Handle empty dataframes
    if (nrow(df) == 0) return(ggempty())

    # Plotting variables
    df$significance <- df[,val]
    df$size <- if(sizes) df$geneset else 1

    # Order by significance value
    df <- df[order(-df[,val]),]
    
    # Abbreviate labels
    label.abrv <- substr(df$label, 1, abrv)
    if (any(duplicated(label.abrv))) {
        stop("Non-unique labels after abbreviating")
    } else {
        df$label.abrv <- factor(label.abrv, levels=label.abrv)   
    }

    if (val == "pval") {
        color.label <- "P-Value"
    }
    if (val == "fdr") {
        color.label <- "FDR"
    }

    ggplot(df, aes(x=label.abrv, y=significance, color=significance, size=log10(size))) +
    geom_point() +
    labs(title=title, y=color.label, color=color.label) +
    scale_color_continuous(low="#E53935", high="#114357", guide=guide_colorbar(reverse=TRUE)) +
    coord_flip() +
    scale_y_continuous(trans=.reverselog_trans(10)) +
    geom_hline(yintercept=0.05, linetype="dotted") +
    guides(size=FALSE) + 
    theme(plot.title=element_text(hjust=0.5),
          axis.title.y=element_blank())
}

#' Visualize hyp/multihyp objects as a dots plot
#'
#' @param hyp_obj A hyp or multihyp object
#' @param top Limit number of genesets shown
#' @param abrv Abbreviation length of geneset labels
#' @param sizes Size dots by geneset sizes
#' @param pval Filter results to be less than pval cutoff
#' @param fdr Filter results to be less than fdr cutoff
#' @param val Choose significance value for plot e.g. c("fdr", "pval")
#' @param title Plot title
#' @param merge Use true to merge a multihyp object into one plot
#' @return A ggplot object
#'
#' @examples
#' genesets <- msigdb_gsets("Homo sapiens", "C2", "CP:KEGG")
#'
#' signature <- c("IDH3B","DLST","PCK2","CS","PDHB","PCK1","PDHA1","LOC642502",
#'                "PDHA2","LOC283398","FH","SDHD","OGDH","SDHB","IDH3A","SDHC",
#'                "IDH2","IDH1","OGDHL","PC","SDHA","SUCLG1","SUCLA2","SUCLG2")
#'
#' hyp_obj <- hypeR(signature, genesets, background=2522)
#'
#' hyp_dots(hyp_obj, val="fdr")
#'
#' @export
hyp_dots <- function(hyp_obj,
                     top=20,
                     abrv=50,
                     sizes=TRUE,
                     pval=1, 
                     fdr=1,
                     val=c("fdr", "pval"), 
                     title="",
                     merge=FALSE) {

    stopifnot(is(hyp_obj, "hyp") | is(hyp_obj, "multihyp"))

    # Default arguments
    val <- match.arg(val)

    # Handling of multiple signatures
    if (is(hyp_obj, "multihyp")) {
        multihyp_obj <- hyp_obj

        # Merge multple signatures into a single plot
        if (merge) {
            .dots_multi_plot(multihyp_obj$data, top, abrv, sizes, pval, fdr, val, title)
        } 
        # Return a list of plots for each signature
        else {
            mapply(function(hyp_obj, title) {

                hyp_dots(hyp_obj,
                         top=top,
                         abrv=abrv,
                         sizes=sizes,
                         pval=pval,
                         fdr=fdr,
                         val=val,
                         title=title)

            }, multihyp_obj$data, names(multihyp_obj$data), USE.NAMES=TRUE, SIMPLIFY=FALSE)
        }
    } 
    else {
        .dots_plot(hyp_obj$data, top, abrv, sizes, pval, fdr, val, title)
    }
}
