using Umbraco.Core.Logging;
using Umbraco.Core;
using Umbraco.Core.Configuration;
using Umbraco.Core.Configuration.UmbracoSettings;
using Umbraco.Core.Models.PublishedContent;
using System.Globalization;
using Umbraco.Core.Configuration.Models;
using Microsoft.Extensions.Options;

namespace Umbraco.Web.Routing
{
    /// <summary>
    /// Provides an implementation of <see cref="IContentFinder"/> that handles page identifiers.
    /// </summary>
    /// <remarks>
    /// <para>Handles <c>/1234</c> where <c>1234</c> is the identified of a document.</para>
    /// </remarks>
    public class ContentFinderByIdPath : IContentFinder
    {
        private readonly ILogger _logger;
        private readonly IRequestAccessor _requestAccessor;
        private readonly WebRoutingSettings _webRoutingSettings;

        public ContentFinderByIdPath(IOptions<WebRoutingSettings> webRoutingSettings, ILogger logger, IRequestAccessor requestAccessor)
        {
            _webRoutingSettings = webRoutingSettings.Value ?? throw new System.ArgumentNullException(nameof(webRoutingSettings));
            _logger = logger ?? throw new System.ArgumentNullException(nameof(logger));
            _requestAccessor = requestAccessor;
        }

        /// <summary>
        /// Tries to find and assign an Umbraco document to a <c>PublishedRequest</c>.
        /// </summary>
        /// <param name="frequest">The <c>PublishedRequest</c>.</param>
        /// <returns>A value indicating whether an Umbraco document was found and assigned.</returns>
        public bool TryFindContent(IPublishedRequest frequest)
        {

            if (frequest.UmbracoContext != null && frequest.UmbracoContext.InPreviewMode == false
                && _webRoutingSettings.DisableFindContentByIdPath)
                return false;

            IPublishedContent node = null;
            var path = frequest.Uri.GetAbsolutePathDecoded();

            var nodeId = -1;
            if (path != "/") // no id if "/"
            {
                var noSlashPath = path.Substring(1);

                if (int.TryParse(noSlashPath, out nodeId) == false)
                    nodeId = -1;

                if (nodeId > 0)
                {
                    _logger.Debug<ContentFinderByIdPath>("Id={NodeId}", nodeId);
                    node = frequest.UmbracoContext.Content.GetById(nodeId);

                    if (node != null)
                    {

                        var cultureFromQuerystring = _requestAccessor.GetQueryStringValue("culture");

                        //if we have a node, check if we have a culture in the query string
                        if (!string.IsNullOrEmpty(cultureFromQuerystring))
                        {
                            //we're assuming it will match a culture, if an invalid one is passed in, an exception will throw (there is no TryGetCultureInfo method), i think this is ok though
                            frequest.Culture = CultureInfo.GetCultureInfo(cultureFromQuerystring);
                        }

                        frequest.PublishedContent = node;
                        _logger.Debug<ContentFinderByIdPath>("Found node with id={PublishedContentId}", frequest.PublishedContent.Id);
                    }
                    else
                    {
                        nodeId = -1; // trigger message below
                    }
                }
            }

            if (nodeId == -1)
                _logger.Debug<ContentFinderByIdPath>("Not a node id");

            return node != null;
        }
    }
}