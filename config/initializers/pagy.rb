# Pagy initializer file
# Basic configuration for Pagy pagination

# Pagy DEFAULT variables
Pagy::DEFAULT[:limit] = 25                                   # items per page
Pagy::DEFAULT[:size]  = 9                                    # nav bar links

# Better user experience - handle invalid pages gracefully
require "pagy/extras/overflow"
Pagy::DEFAULT[:overflow] = :last_page
