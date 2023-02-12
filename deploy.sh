#!/bin/bash
jekyll b
sudo rm -rf /var/www/html/*
sudo cp -r ./_site/* /var/www/html
echo "Deploy success!"
