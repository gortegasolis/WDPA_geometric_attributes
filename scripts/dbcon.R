# Load environment variables from .env file
load_dot_env(".env")

# Disconnect if there is a connection named con open
if (exists("con")) {
  dbDisconnect(con)
}

# Create the connection
con <- dbConnect(Postgres(),
  dbname = "World_Protected_Areas",
  host = "localhost",
  port = 5432,
  user = "atlasadmin",
  password = Sys.getenv("PGPASSWORD")
)