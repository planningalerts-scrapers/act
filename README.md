# ACT Planning & Land Authority

This is a scraper that runs on [Morph](https://morph.io). To get started [see the documentation](https://morph.io/documentation)


Add any issues to https://github.com/planningalerts-scrapers/issues/issues

## To run the scraper

    bundle exec ruby scraper.rb

### Expected output

    Saving UNIT 17, 2 YULE STREET, AMAROO, ACT...
    Saving 60 BARADA CRESCENT, ARANDA, ACT...
    ...
    Saving GUNN STREET, STRAHAN ROW, YARRALUMLA, ACT...
    Saving 19,21 MACGILLIVRAY STREET, YARRALUMLA, ACT...
    Finished - added 56 records

Execution time under a minute

## To run style and coding checks

    bundle exec rubocop

## To check for security updates

    gem install bundler-audit
    bundle-audit
