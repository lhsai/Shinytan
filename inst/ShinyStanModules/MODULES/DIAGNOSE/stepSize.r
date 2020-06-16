stepSizeUI <- function(id){
  ns <- NS(id)
  
  tagList(
    wellPanel(
      fluidRow(
        column(width = 4), 
        column(width = 4),
        column(width = 4, align = "right",
                 div(style = "width: 100px;",
                     numericInput(
                       ns("diagnostic_chain"),
                       label = h5(textOutput(ns("diagnostic_chain_text"))),
                       value = 0,
                       min = 0,
                       # don't allow changing chains if only 1 chain
                       max = ifelse(shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_chain == 1, 0, shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_chain)
                     )
                 )
        )
      ),
      fluidRow(
        align = "right",
        plotOptionsUI(ns("options"))
      )
    ),
    plotOutput(ns("plot1")),
    checkboxInput(ns("showCaption"), "Show Caption", value = TRUE),
    hidden(
      uiOutput(ns("caption"))
    ),
    hr(), 
    # checkboxInput(ns("report"), "Include in report?")
    downloadButton(ns('downloadPlot'), 'Download Plot', class = "downloadReport"),
    downloadButton(ns('downloadRDS'), 'Download RDS', class = "downloadReport")
  )
}




stepSize <- function(input, output, session){
  
  visualOptions <- callModule(plotOptions, "options")  
  chain <- reactive(input$diagnostic_chain)
  include <- reactive(input$report)
    
  observe({
    toggle("caption", condition = input$showCaption)
  })
  
    output$diagnostic_chain_text <- renderText({
      if (chain() == 0)
        return("All chains")
      paste("Chain", chain())
    })
    
    plotOut <- function(chain) {
      
    if(chain != 0) {
      mcmc_nuts_stepsize(
        x = nuts_params(list(shinystan:::.sso_env$.SHINYSTAN_OBJECT@sampler_params[[chain]]) %>%
                          lapply(., as.data.frame) %>%
                          lapply(., filter, row_number() > shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup) %>%
                          lapply(., as.matrix)),
        lp = data.frame(Iteration = rep(1:(shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter - shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup), 1),
                        Value = c(shinystan:::.sso_env$.SHINYSTAN_OBJECT@posterior_sample[(shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup + 1):shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter, chain,"log-posterior"]),
                        Chain = rep(chain, each = (shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter - shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup))) 
      )
    } else {
      mcmc_nuts_stepsize(
        x = nuts_params(shinystan:::.sso_env$.SHINYSTAN_OBJECT@sampler_params %>%
                          lapply(., as.data.frame) %>%
                          lapply(., filter, row_number() > shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup) %>%
                          lapply(., as.matrix)),
        lp = data.frame(Iteration = rep(1:(shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter - shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup), shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_chain),
                        Value = c(shinystan:::.sso_env$.SHINYSTAN_OBJECT@posterior_sample[(shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup + 1):shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter, ,"log-posterior"]),
                        Chain = rep(1:shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_chain, each = (shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter - shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup))) 
      )
    }
    }
    
    output$plot1 <- renderPlot({
      # change plot theme based on selection for this plot, thereafter change back.
      save_old_theme <- bayesplot_theme_get()
      color_scheme_set(visualOptions()$color)
      bayesplot_theme_set(eval(parse(text = select_theme(visualOptions()$theme)))) 
      out <- plotOut(chain = chain()) 
      bayesplot_theme_set(save_old_theme)
      out
    })
    
    
    captionOut <- function(){
      HTML(paste0("These are plots of the <i> integrator step size per chain</i> (x-axis)",
                  " against the <i> log-posterior </i> (y-axis top panel) and against the",
                  " <i> acceptance statistic </i> (y-axis bottom panel) of the sampling algorithm.",
                  " If the step size is too large, the integrator will be inaccurate and too many proposals will be rejected.",
                  " If the step size is too small, the many small steps lead to long simulation times per interval.",
                  " Thus the goal is to balance the acceptance rate between these extremes.",
                  " Good plots will show full exploration of the log-posterior and moderate to high acceptance rates",
                  " for all chains and step sizes.", " Bad plots might show incomplete exploration of the log-posterior",
                  " and lower acceptance rates for larger step sizes."))
    }
    output$caption <- renderUI({
      captionOut()
    })
    
    output$downloadPlot <- downloadHandler(
      filename = 'stepsizePlot.pdf',
      content = function(file) {
        # ggsave(file, gridExtra::arrangeGrob(grobs = downloadSelection()))
        pdf(file)
        save_old_theme <- bayesplot_theme_get()
        color_scheme_set(visualOptions()$color)
        bayesplot_theme_set(eval(parse(text = select_theme(visualOptions()$theme)))) 
        out <- plotOut(chain = chain()) 
        bayesplot_theme_set(save_old_theme)
        print(out) # hide 'bins = 30' message ggplot
        dev.off()
      })
    
    
    output$downloadRDS <- downloadHandler(
      filename = 'stepsizePlot.rds',
      content = function(file) {
        save_old_theme <- bayesplot_theme_get()
        color_scheme_set(visualOptions()$color)
        bayesplot_theme_set(eval(parse(text = select_theme(visualOptions()$theme)))) 
        out <- plotOut(chain = chain()) 
        bayesplot_theme_set(save_old_theme)
        saveRDS(out, file)
      })  
    
    return(reactive({
      if(include() == TRUE){
        # customized plot options return without setting the options for the other plots
        save_old_theme <- bayesplot_theme_get()
        color_scheme_set(visualOptions()$color)
        bayesplot_theme_set(eval(parse(text = select_theme(visualOptions()$theme)))) 
        out <- list(plot = plotOut(chain = chain()), 
                    caption = captionOut())
        bayesplot_theme_set(save_old_theme)
        out
      } else {
        NULL
      }
    }))
  
}