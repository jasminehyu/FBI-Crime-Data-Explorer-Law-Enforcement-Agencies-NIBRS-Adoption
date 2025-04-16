
#Author: Jasmine Yu

# Usage Notice: This work is created by Jasmine Yu. 
# Feel free to share or reference it, but please credit the source and contact me for permission before using it in any other context. Thank you for respecting creative work.
# Contact: jasmineyuhhy@gmail.com


# import required libraries
library(shiny)
library(shinythemes)
library(leaflet)
library(plotly)
library(DT)
library(dplyr)
library(ggplot2)

df<- tidytuesdayR::tt_load('2025-02-18')$agencies
df <- df%>%filter(!is.na(agency_type))%>% mutate(year=format(nibrs_start_date,"%Y"))

all_states <- unique(df$state_abbr)
all_agency_type <- unique(df$agency_type)

#User Interface
ui <- fluidPage(
  theme = shinytheme("flatly"),
  titlePanel("FBI Crime Data Explorer: Law Enforcement Agencies & NIBRS Adoption"),
  
  sidebarLayout(
    sidebarPanel(
      p("This interactive dashboard is designed to explore the geographic distribution and adoption trends of law enforcement 
               agencies participating in the FBI’s NIBRS reporting system."),
      h4('Filter'),
      p("Use the dropdown menu to select a specific state and explore its regional agency distribution."),
      p("Choose one or more agency types to refine your analysis and focus on specific law enforcement categories."),
      
      
      selectInput("state", "Select State:",
                  choices = all_states,
                  selected = all_states[1]),
      checkboxGroupInput("type", "Select Agency Type:",
                         choices = all_agency_type,
                         selected = all_agency_type),
      actionButton("refresh", "Update Map", icon = icon("sync"))
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("📍 Geographic Distribution",
                 p("This interactive map displays the geographic distribution of law enforcement agencies across the selected state. 
                  Agencies participating in NIBRS are marked in ", 
                   span("green", style="color:forestgreen;"), 
                   " while non-participating agencies appear in ", 
                   span("red", style="color:firebrick;"), ". 
                  Click on a marker to view agency details."),
                 leafletOutput("map", height = "600px")),
        
        tabPanel("📈 NIBRS Adoption Trends",
                 p("This line chart illustrates the cumulative percentage of law enforcement agencies that have adopted NIBRS reporting over time. 
                  Use the filters to compare adoption trends across different agency types."),
                 plotlyOutput("trend", height = "600px")),
        
        tabPanel("📋 Data Table",
                 p("This table provides a detailed view of the dataset, allowing users to explore the specific agencies included in the analysis. 
                  Use the filters/search box to refine the data displayed."),
                 DTOutput("table"))
      )
    )
  )
)

# Server
server <- function(input, output) {
  
  # Reactive Dataset reflecting selected data
  filtered_data <- reactive({
    df %>%
      filter(
        state_abbr %in% input$state,
        agency_type %in% input$type
      )
  }) 
  
  #Leaflet Map: Geographic information
  output$map <- renderLeaflet({
    leaflet(data = filtered_data()) %>% 
      addTiles() %>% 
      addCircleMarkers(
        lng = ~longitude, lat = ~latitude,
        color = ~ifelse(is_nibrs == TRUE,"forestgreen" , "firebrick"),
        fillOpacity = 0.6,  
        opacity = 0.8,
        radius=2,
        popup = ~paste("Agency =", agency_name, "<br>",
                       "Type =", agency_type, "<br>",
                       "State =", state_abbr, "<br>",
                       "Join Date =", ifelse(is.na(nibrs_start_date), "N/A", format(nibrs_start_date, "%Y-%m-%d")), "<br>"),
        label = ~agency_name)
  })
  
  # Line Chart: NIBRS Adoption trends over time
  output$trend <- renderPlotly({
    total_agencies= filtered_data() %>%
      group_by(agency_type) %>%
      summarise(total_count = n(), .groups = "drop")
    
    p=filtered_data() %>%
      filter(is_nibrs == TRUE) %>%
      group_by(year, agency_type) %>%
      summarise(num_participant = n()) %>%
      ungroup() %>% 
      arrange(agency_type, year) %>% 
      group_by(agency_type) %>% 
      mutate(cumulative_num=cumsum(num_participant)) %>% 
      left_join(total_agencies, by="agency_type") %>% 
      mutate(accumulated_percentage =(cumulative_num/total_count)*100) %>%  
      ggplot(aes(x = year, y =accumulated_percentage, color = agency_type, group = agency_type)) +
      geom_point(size=1)+
      geom_line() +
      labs(title = "NIBRS Adoption Trends Over Time",
           x = "Year", y = "Percentage of Agencies Participating") +
      theme_minimal()
    ggplotly(p)
  })
  
  # Data Table
  output$table <- renderDT({
    datatable(filtered_data(), options = list(pageLength=10))
  })
}

shinyApp(ui,server)