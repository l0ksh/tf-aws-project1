#subnet_prefix = "10.0.1.0/24"      # default method
#subnet_prefix   = ["10.0.1.0/24", "10.0.5.0/24"] # list method
subnet_prefix   = [{cidr_block = "10.0.1.0/24", name = "prod_subnet"}, {cidr_block = "10.0.5.0/24", name = "dev_subnet"}]