﻿<%@ WebHandler Language="C#" Class="SignNow" %>
// <copyright>
// Copyright 2013 by the Spark Development Network
//
// Licensed under the Rock Community License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.rockrms.com/license
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// </copyright>
//
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Web;

using Newtonsoft.Json;

using Rock;
using Rock.Data;
using Rock.Model;
using Rock.Security;

public class SignNow : IHttpHandler
{
    private HttpRequest request;
    private HttpResponse response;

    public void ProcessRequest( HttpContext context )
    {
        request = context.Request;
        response = context.Response;

        response.ContentType = "text/plain";

        if ( request.HttpMethod != "POST" )
        {
            response.Write( "Invalid request type." );
            response.StatusCode = HttpStatusCode.NotAcceptable.ConvertToInt();
            return;
        }

        string postedData = string.Empty;
        using ( var reader = new StreamReader( request.InputStream ) )
        {
            postedData = reader.ReadToEnd();
        }

        var signNowData = JsonConvert.DeserializeObject<SignNowData>( postedData );
        if ( signNowData == null )
        {
            response.Write( "Invalid Data." );
            response.StatusCode = HttpStatusCode.BadRequest.ConvertToInt();
            return;
        }

        if ( signNowData.meta.event_name == "document.update" )
        {
            using ( var rockContext = new RockContext() )
            {
                var document = new SignatureDocumentService( rockContext ).GetByDocumentKey( signNowData.content.document_id );
                if ( document != null )
                {
                    document.Status = SignatureDocumentStatus.Signed;
                    document.LastStatusDate = RockDateTime.Now;
                }
                rockContext.SaveChanges();

                var signNowComponent = DigitalSignatureContainer.GetComponent( "Rock.Security.DigitalSignature.SignNow" );
                if ( signNowComponent != null )
                {
                    var errorMessages = new List<string>();
                    string documentPath = signNowComponent.GetDocument( document, context.Server.MapPath( "~/App_Data/Cache/SignNow" ), out errorMessages );
                    if ( !string.IsNullOrWhiteSpace( documentPath ) )
                    {
                        var binaryFileService = new BinaryFileService( rockContext );
                        BinaryFile binaryFile = new BinaryFile();
                        binaryFile.Guid = Guid.NewGuid();
                        binaryFile.IsTemporary = false;
                        binaryFile.BinaryFileTypeId = document.SignatureDocumentType.BinaryFileTypeId;
                        binaryFile.MimeType = "application/pdf";
                        binaryFile.FileName = new FileInfo( documentPath ).Name;
                        binaryFile.ContentStream = new FileStream( documentPath, FileMode.Open );
                        binaryFileService.Add( binaryFile );
                        rockContext.SaveChanges();

                        document.BinaryFileId = binaryFile.Id;
                        rockContext.SaveChanges();

                        File.Delete( documentPath );
                    }
                }
            }

            response.Write( String.Format( "Successfully processed '{0}' message", signNowData.meta.event_name ) );
            response.StatusCode = 200;
        }
    }

    public bool IsReusable
    {
        get
        {
            return false;
        }
    }

    public class SignNowData
    {
        public SignNowMeta meta { get; set; }
        public SignNowContent content { get; set; }
    }

    public class SignNowMeta
    {
        public int timestamp { get; set; }
        [JsonProperty( PropertyName = "event" )]
        public string event_name { get; set; }
        public string environment { get; set; }
        public string callback_url { get; set; }
        public string access_token { get; set; }
    }

    public class SignNowContent
    {
        public string document_id { get; set; }
        public string document_name { get; set; }
        public string user_id { get; set; }
    }
}