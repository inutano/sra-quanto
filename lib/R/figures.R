# R script to draw figures of Quanto manuscript

# Load library
library(ggplot2)
library(gridExtra)
library(stringr)

# Load data
argv <- commandArgs(trailingOnly=T)
pathToData <- argv[1]
df <- read.delim(pathToData)
df <- subset(df, df$total_sequence > 0)

# Prepare colour palette - http://www.cookbook-r.com/Graphs/Colors_(ggplot2)/
cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")


#
# Figure 1
#

# Taxonomy metadata

taxTop20 <- row.names(as.data.frame(summary(df$taxonomy_scientific_name, max=20)))
df$taxonomy_scientific_name <- as.character(df$taxonomy_scientific_name)
df$taxTop20 <- ifelse(df$taxonomy_scientific_name %in% taxTop20, df$taxonomy_scientific_name, "Other")
df$taxonomy_scientific_name <- as.factor(df$taxonomy_scientific_name)
df$taxTop20 <- as.factor(df$taxTop20)

# Calculate throughput

df$throughput <- df$total_sequences * df$mean_sequence_length

# Barplot template

barplot <- function(data, xAxisData, xLabel, title){
  p <- ggplot(data, aes(reorder(xAxisData, xAxisData, function(x)-length(x))))
  p <- p + geom_bar()
  p <- p + labs(x = xLabel, title = title)
  p <- p + theme(
    axis.text.x = element_text(angle=45, hjust=1),
    plot.background = element_rect(fill="transparent", colour=NA),
    panel.background = element_rect(fill="transparent", colour=NA),
    panel.grid.major = element_line(color="gray", size=.1),
    panel.grid.minor = element_line(color="gray", size=.05),
    plot.title = element_text(size = rel(2), hjust=0)
  )
  return(p)
}

# Fig.1a
barplotStrategy <- barplot(df, df$library_strategy, "Library strategy", "a")

# Fig.1b
barplotTaxonomy <- barplot(df, df$taxTop20, "Sample organism", "b")

# Fig.1c
barplotInstrument <- barplot(df, df$instrument_model, "Instrument model", "c")

# Combine and save
ggsave(
  plot = grid.arrange(barplotStrategy, barplotTaxonomy, barplotInstrument),
  file = "./figure1.pdf",
  dpi = 900
)

#
# Figure 2
#

# histogram template

# library strategy

strTop8 <- row.names(as.data.frame(summary(df$library_strategy, max=8)))
df$library_strategy <- as.character(df$library_strategy)
df$strTop8 <- ifelse(df$library_strategy %in% strTop8, df$library_strategy, "OTHER")
df$library_strategy <- as.factor(df$library_strategy)
df$strTop8 <- as.factor(df$strTop8)

# Histogram template

histogramOverall <- function(data, xAxisData, xLabel, title, fill=NULL, fillLegend=NULL){
  p <- ggplot(data, aes(xAxisData, fill=fill))
  p <- p + geom_histogram(bins=sqrt(nrow(data)))
  p <- p + theme(
    plot.background = element_rect(fill="transparent", colour=NA),
    panel.background = element_rect(fill="transparent", colour=NA),
    panel.grid.major = element_line(color="gray", size=.1),
    panel.grid.major = element_line(color="gray", size=.05)
  )
  p <- p + labs(x = xLabel, title = title, fill = fillLegend)
  p <- p + scale_fill_manual(values=cbPalette)
  return(p)
}

# Fig.2a
histoStrategy <- histogramOverall(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "a"
)

# Fig.2b
histoStrategyColoured <- histogramOverall(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "b",
  fill = df$library_source,
  fillLegend = "Library source"
)

# Fig.2c
histoBaseCall <- histogramOverall(
  df,
  df$overall_median_sequence_quality,
  "Median base call accuracy per experiment",
  "c"
)

# Fig.2d
histoBaseCallColoured <- histogramOverall(
  df,
  df$overall_median_sequence_quality,
  "Median base call accuracy per experiment",
  "d",
  fill = df$strTop8,
  fillLegend = "Library strategy"
)

# Combine and save
ggsave(
  plot = grid.arrange(histoStrategy, histoStrategyColoured, histoBaseCall, histoBaseCallColoured, ncol=2),
  file = "./figure2.pdf",
  dpi = 900
)

#
# Figure 3
#

# instrument vendors

illumina <- c("HiSeq X Ten", "NextSeq 500")
df$instrument_model <- as.character(df$instrument_model)
df$instrument_vendor <- ifelse(df$instrument_model %in% illumina, "Illumina", df$instrument_model)
df$instrument_vendor <- str_replace(df$instrument_vendor, " .+", “”)
df$instrument_model <- as.factor(df$instrument_model)
df$instrument_vendor <- as.factor(df$instrument_vendor)

# Faceted histogram template

histoFaceted <- function(data, xAxisData, xLabel, title){
  p <- ggplot(data, aes(xAxisData, fill=data$instrument_vendor))
  p <- p + geom_histogram(bins=sqrt(nrow(data)))
  p <- p + theme(
    plot.background = element_rect(fill="transparent", colour=NA),
    panel.background = element_rect(fill="transparent", colour=NA),
    panel.grid.major = element_line(color="gray", size=.1),
    panel.grid.major = element_line(color="gray", size=.05)
  )
  p <- p + labs(x = , title = title, fill = "Instrument vendor")
  p <- p + scale_fill_manual(values=cbPalette)
  return(p)
}

# Data for figure 3, human data and top8 strategies
data3 <- subset(df, df$taxonomy_id == "9606" & df$strTop8 != "OTHER")

# Fig.3a - without legend
histoFacetedNumbers <- histoFaceted(
  data3,
  log10(data3$total_sequences),
  "Total number of sequences per experiment (log10)",
  "a"
) + theme(legend.position="none")

# Fig.3b - with legend
histoFacetedLength <- histoFaceted(
  data3,
  log10(data3$median_sequence_length),
  "Median sequence read length per experiment (log10)",
  "b"
)

# Fig.3c - without legend
histoFacetedThroughput <- histoFaceted(
  data3,
  log10(data3$throughput),
  "Sequencing throughput per experiment (log10)",
  "c"
) + theme(legend.position="none")

# Fig.3d - without legend
histoFacetedBaseCall <- histoFaceted(
  data3,
  data3$overall_median_sequence_quality,
  "Median base call accuracy per experiment",
  "d"
) + theme(legend.position="none")

# Combine and save
ggsave(
  plot = grid.arrange(histoFacetedNumbers, histoFacetedLength, histoFacetedThroughput, histoFacetedBaseCall, ncol=2),
  file = "./figure3.pdf",
  dpi = 900
)

#
# Figure 4
#

give.n <- function(x){ return(c(y = mean(x) * 1.3, label = length(x))) }

timeSeriesBoxplot <- function(data, yAxisData, yLabel, title){
  p <- ggplot(data, aes(x = data$qtr, y = yAxisData))
  p <- p + geom_boxplot(outlier.shape=NA)
  p <- p + stat_summary(fun.y = mean, geom = "line", aes(group = 1))
  p <- p + theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.minor = element_line(color = "gray", size = .05)
  )
  p <- p + labs(x = "Quarters", y = yLabel, title = title)
  p <- facet_wrap(~strTop8)
  return p
}

# Data for figure 4, valid date values, human and top8 strategies
df$submitted_date <- as.POSIXct(df$submitted_date, format="%Y-%m-%dT%H:%M:%SZ", tz="UTC")
df_date <- df[!is.na(df$submitted_date),]
df_date$qtr <- paste(format(df_date$submitted_date, "%Y"), quarters(df_date$submitted_date), sep="/")
data4 <- subset(df_date, df_date$year!="2016" & df_date$taxonomy_id == "9606" & df_date$strTop8 != "OTHER")

# Fig.4a
boxplotNumbers <- timeSeriesBoxplot(data4, log10(data4$total_sequences), "Total number of sequences per experiment (log10)", "a")

# Fig.4b
boxplotLength <- timeSeriesBoxplot(data4, log10(data4$median_sequence_length), "Median sequence length per experiment (log10)", "b")

# Fig.4c
boxplotThroughput <- timeSeriesBoxplot(data4, log10(data4$throughput), "Sequencing throughput per experiment (log10)", "c")

# Fig.4d
boxplotBasecall <- timeSeriesBoxplot(data4, data4$overall_median_sequence_quality, "Median base call accuracy per experiment", "d")

# Combine and save
ggsave(
  plot = grid.arrange(boxplotNumbers, boxplotLength, boxplotThroughput, boxplotBasecall, ncol=2),
  file = "./figure4.pdf",
  dpi = 900
)

#
# Supplementary Figure 1
#
