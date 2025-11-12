FROM mcr.microsoft.com/dotnet/sdk:8.0

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Install make for running Makefile targets
RUN apt-get update && apt-get install -y \
    make \
    && rm -rf /var/lib/apt/lists/*

# Copy project file
COPY Chess.csproj ./

# Restore dependencies
RUN dotnet restore

# Copy source code
COPY . ./

# Build the application
RUN dotnet build -c Release --no-restore

# Run the chess engine
CMD ["dotnet", "bin/Release/net8.0/chess.dll"]
