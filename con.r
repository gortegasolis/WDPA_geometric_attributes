# Database connection
pacman::p_load(DBI, RPostgres, askpass)

# Connect to the database
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "World_Protected_Areas",
  host = "localhost",
  port = 5432,
  user = "atlasadmin",
  password = Sys.getenv("PGPASSWORD")
)
