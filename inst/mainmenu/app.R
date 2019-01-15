#This is the Shiny App for the main menu of DSAIDE

#get names of all existing apps
appdir = system.file("allapps", package = "DSAIDE") #find path to apps
appNames = list.dirs(path = appdir, full.names = FALSE, recursive = FALSE)

currentapp = NULL #global server variable for currently loaded app
currentapptitle = NULL #global server variable for currently loaded app
currentsimfct <<- NULL #global server variable for current simulation function
currentmodelnplots <<- NULL #global server variable for number of plots
currentmodeltype <<- NULL #global server variable for model type to run
currentotherinputs <<-  NULL
currentdocfilename <<- NULL


#this function is the server part of the app
server <- function(input, output, session)
{
  #######################################################
  #start code that listens to model selection buttons and creates UI for a chosen model
  #######################################################
  lapply(appNames, function(appName)
  {
    observeEvent(input[[appName]],
    {
      currentapp <<- appName #assign currently chosen app to global app variable
      #file name for documentation
      currentdocfilename <<- paste0(appdir,'/',currentapp,'/',currentapp,'_documentation.html')

      output$plot <- NULL
      output$text <- NULL

      #load/source an R settings file that contains additional information for a given app
      #variable simfilename in the settings file is the name of the simulation function or NULL
      #variable modeltype in the settings file is the type of the model to be run or NULL
      #variable mbmoddelfile is the name of the mbmodel Rdata file or NULL
      #variable otherinputs contains additional shiny UI elements
      #one wants to display that are not generated automaticall by functions above
      #for instance all non-numeric inputs need to be provided separately. If not needed, it is NULL
      settingfilename = paste0(appdir,'/',currentapp,'/',currentapp,'_settings.R')
      source(settingfilename) #source the file with additional settings to load them
      currentsimfct <<- simfunction
      currentmodelnplots <<- nplots
      currentmodeltype <<- modeltype
      currentotherinputs <<-  otherinputs
      currentapptitle <<- apptitle

      #extract function inputs and turn them into shiny input elements
      #this uses the 1st function provided by the settings file and stored in currentsimfct
      #this only works for numeric inputs, any others will be removed and need to be
      #added to shiny UI using the settings file
      #indexing sim function in case there are multiple
      DSAIDE::generate_shinyinput(mbmodel = currentsimfct[1], otherinputs = currentotherinputs, output = output)

      #display all extracted inputs on the analyze tab
      output$analyzemodel <- renderUI({
          tagList(
            tags$div(id = "shinyapptitle", currentapptitle),
            tags$hr(),
            #Split screen with input on left, output on right
            fluidRow(
              column(6,
                h2('Simulation Settings'),
                wellPanel(uiOutput("modelinputs"))
              ), #end sidebar column for inputs
              column(6,
                h2('Simulation Results'),
                plotOutput(outputId = "plot"),
                htmlOutput(outputId = "text")
              ) #end column with outcomes
            ), #end fluidrow containing input and output
            #Instructions section at bottom as tabs
            h2('Instructions'),
            #use external function to generate all tabs with instruction content
            withMathJax(do.call(tabsetPanel, generate_documentation(currentdocfilename)))
          ) #end tag list
        }) # End renderUI for analyze tab

      #once UI for the model in the analyze tab is created, switch to that tab
      updateNavbarPage(session, "DSAIDE", selected = "Analyze")
    }) #end observeEvent for the analyze tab

  }) #end lapply function surrounding observeEvent to build app

    #######################################################
    #end code that listens to model selection buttons and creates UI for a chosen model
    #######################################################


    #######################################################
    #start code that listens to the 'run simulation' button and runs a model for the specified settings
    #######################################################
    observeEvent(input$submitBtn, {


      #run model with specified settings
      #run simulation, show a 'running simulation' message
      withProgress(message = 'Running Simulation',
                   detail = "This may take a while", value = 0,
                   {
                     #extract current model settings from UI input elements
                     x1=isolate(reactiveValuesToList(input)) #get all shiny inputs
                     #x1=as.list( c(g = 1, U = 100)) #get all shiny inputs
                     x2 = x1[! (names(x1) %in% appNames)] #remove inputs that are action buttons for apps
                     x3 = (x2[! (names(x2) %in% c('submitBtn','Exit','DSAIDE') ) ]) #remove further inputs
                     modelsettings = x3[!grepl("*selectized$", names(x3))] #remove any input with selectized
                     if (is.null(modelsettings$nreps)) {modelsettings$nreps <- 1} #if there is no UI input for replicates, assume reps is 1
                     #if no random seed is set in UI, set it to 123.
                     if (is.null(modelsettings$rngseed)) {modelsettings$rngseed <- 123}
                     #if there is a supplied model type from the settings file, use that one
                     #note that input for model type might be still 'floating around' if a previous model was loaded
                     #not clear how to get rid of old shiny input variables from previously loaded models
                     if (!is.null(currentmodeltype)) { modelsettings$modeltype <- currentmodeltype}
                     modelsettings$nplots <- currentmodelnplots
                     result <- run_model(modelsettings = modelsettings, modelfunction  = currentsimfct)

                     #create plot from results
                     output$plot  <- renderPlot({
                       generate_plots(result)
                     }, width = 'auto', height = 'auto')
                     #create text from results
                     output$text <- renderText({
                       generate_text(result) })

                   }) #end with-progress wrapper
    }, #end the expression being evaluated by observeevent
    #ignoreNULL = TRUE, ignoreInit = TRUE
    ) #end observe-event for analyze model submit button

    #######################################################
    #end code that listens to the 'run simulation' button and runs a model for the specified settings
    #######################################################

  #######################################################
  #end code blocks that contain the analyze functionality
  #######################################################


  observeEvent(input$Exit, {
    stopApp('Exit')
  })

} #ends the server function for the app



#######################################################
#This is the UI for the Main Menu of DSAIDE
#######################################################

ui <- fluidPage(
  includeCSS("../media/dsaide.css"), #use custom styling
  tags$div(id = "shinyheadertitle", "DSAIDE - Dynamical Systems Approach to Infectious Disease Epidemiology"),
  tags$div(id = "shinyheadertext",
    "A collection of Shiny/R Apps to explore and simulate infectious disease models.",
    br()),
  tags$div(id = "infotext", paste('This is DSAIDE version ',utils::packageVersion("DSAIDE"),' last updated ', utils::packageDescription('DSAIDE')$Date,'.',sep='')),
  tags$div(id = "infotext", "Written and maintained by", a("Andreas Handel", href="http://handelgroup.uga.edu", target="_blank"), "with contributions from", a("others.",  href="https://github.com/ahgroup/DSAIDE#contributors", target="_blank")),
  navbarPage(title = "DSAIDE", id = "DSAIDE", selected = 'Menu',
             tabPanel(title = "Menu",
                      tags$div(class='mainsectionheader', 'The Basics'),
                      fluidRow(
                               actionButton("basicsir", "Basic SIR model", class="mainbutton"),
                               actionButton("idcharacteristics", "Characteristics of ID", class="mainbutton"),
                               actionButton("idpatterns", "ID Patterns", class="mainbutton"),
                        class = "mainmenurow"
                      ), #close fluidRow structure for input

                      tags$div(class='mainsectionheader', 'The Reproductive Number'),
                      fluidRow(
                        actionButton("reproductivenumber1", "Reproductive Number 1", class="mainbutton"),  
                        actionButton("reproductivenumber2", "Reproductive Number 2", class="mainbutton"),  
                        class = "mainmenurow"
                      ), #close fluidRow structure for input

                      tags$div(class='mainsectionheader', 'Controlling Infectious Diseases'),
                      fluidRow(
                        actionButton("idcontrol1", "ID Control 1", class="mainbutton"),  
                        actionButton("idcontrol2", "ID Control 2", class="mainbutton"), 
                        class = "mainmenurow"
                      ), #close fluidRow structure for input

                      tags$div(class='mainsectionheader', 'Types of Transmission'),
                      fluidRow(
                        actionButton("directtransmission", "Direct Transmission", class="mainbutton"),  
                      actionButton("environmentaltransmission", "Environmental Transmission", class="mainbutton"),
                        actionButton("vectortransmission", "Vector Transmission", class="mainbutton"),
                        class = "mainmenurow"
                      ), #close fluidRow structure for input
                      
                      tags$div(class='mainsectionheader', 'Stochastic Models'),
                      fluidRow(
                        actionButton("stochasticsir", "Stochastic SIR Model", class="mainbutton"),  
                         actionButton("stochasticseir", "Stochastic SEIR Model", class="mainbutton"),
                         actionButton("evolutionarydynamics", "Evolutionary Dynamics", class="mainbutton"),
                        class = "mainmenurow"
                      ),
                      
                      tags$div(class='mainsectionheader', 'Further topics'),
                      fluidRow(
                        actionButton("hostheterogeneity", "Host Heterogeneity", class="mainbutton"),  
                       actionButton("multipathogen", "Multi-Pathogen Dynamics", class="mainbutton"),
                        class = "mainmenurow"
                      ), #close fluidRow structure for input
                      withTags({
                        div(style = "text-align:left", class="infotext",

                            p('This collection of model simulations/apps provides covers various aspects of infectious disease epidemiology from a dynamical systems model perspective. The software is meant to provide you with a "learning by doing" approach. You will likely learn best and fastest by using this software as part of a course on the topic, taught by a knowledgable instructor who can provide any needed background information and help if you get stuck. Alternatively, you should be able to self-learn and obtain the needed background information by going through the materials listed in the "Further Information" section of the apps.'),
                            p('The main way of using the simulations is through this graphical interface. You can also access the simulations directly. This requires a bit of R coding but gives you many more options of things you can try. See the package vignette or the "Further Information" section of the apps for more on that.'),
                            p('You should start with the Basic SIR app and read all its instruction tabs since they contain information relevant for all apps. The remaining simulations are ordered in a sequence that makes sense for learning the material, so it is best to go in order (each section top to bottom, within each section left to right). Some simulations also build on earlier ones. But you can possibly also jump around and still be ok.')
                        )
                      }), #close withTags function
                      p('Have fun exploring the models!', class='maintext'),
                      fluidRow(
                        actionButton("Exit", "Exit", class="exitbutton"),
                        class = "mainmenurow"
                      ) #close fluidRow structure for input

             ), #close "Menu" tabPanel tab

             tabPanel("Analyze",
                      fluidRow(
                        column(12,
                               uiOutput('analyzemodel')
                        )
                        #class = "mainmenurow"
                      ) #close fluidRow structure for input
             ) #close "Analyze" tab
  ), #close navbarPage

  tagList( hr(),
           p('All text and figures are licensed under a ',
           a("Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.", href="http://creativecommons.org/licenses/by-nc-sa/4.0/", target="_blank"),
           'Software/Code is licensed under ',
           a("GPL-3.", href="https://www.gnu.org/licenses/gpl-3.0.en.html" , target="_blank")
           ,
           br(),
           "The development of this package was partially supported by NIH grant U19AI117891.",
           align = "center", style="font-size:small") #end paragraph
  )
) #end fluidpage

shinyApp(ui = ui, server = server)