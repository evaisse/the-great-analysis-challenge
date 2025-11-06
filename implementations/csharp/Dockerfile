FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /app

# Copy project file
COPY Chess.csproj ./

# Restore dependencies
RUN dotnet restore

# Copy source code
COPY . ./

# Build the application
RUN dotnet build -c Release --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/runtime:8.0

WORKDIR /app

# Copy build artifacts from build stage
COPY --from=build /app/bin/Release/net8.0/ ./

# Run the chess engine
CMD ["dotnet", "chess.dll"]
