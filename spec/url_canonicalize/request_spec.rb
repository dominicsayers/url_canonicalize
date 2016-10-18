describe URLCanonicalize::Request do
  it 'does stuff' do
    url = 'http://www.bizjournals.com/sanfrancisco/blog/techflash/2016/10/peter-thiel-plans-millions-donald-trump-elec'\
          'tion.html?ana=RSS%26s%3Darticle_search&utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+bizj_sanf'\
          'rancisco+%28San+Francisco+Business+Times%2 (...)'

    expect { URLCanonicalize.fetch(url) }.to raise_error(URLCanonicalize::Exception::URI)
  end
end
